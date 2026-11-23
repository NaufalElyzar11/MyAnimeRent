import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myanimerent/event/catalog.dart';
import 'package:myanimerent/event/catalog_controller.dart';
import 'package:myanimerent/event/catalog_repository.dart';
import 'package:myanimerent/event/catalog_search.dart';
import 'package:myanimerent/event/contact_service.dart';

Map<String, dynamic> fixtureData() =>
    jsonDecode(File('assets/event/catalog.json').readAsStringSync())
        as Map<String, dynamic>;
CatalogSnapshot fixture() => CatalogSnapshot.parse(jsonEncode(fixtureData()));

class MemoryAssets extends CachingAssetBundle {
  MemoryAssets(this.files);
  final Map<String, Uint8List> files;
  @override
  Future<ByteData> load(String key) async {
    if (!files.containsKey(key)) throw StateError('missing asset');
    return ByteData.sublistView(files[key]!);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  group('Pencarian katalog event', () {
    final snapshot = fixture();
    List<String> ids(CatalogQuery q) =>
        searchSnapshot(snapshot, q).items.map((p) => p.id).toList();
    test('query pendek dan normalisasi huruf, spasi, tanda baca', () {
      expect(ids(const CatalogQuery(text: '2B')), ['demo-2b-a', 'demo-2b-b']);
      expect(ids(const CatalogQuery(text: '  2-B  ')), [
        'demo-2b-a',
        'demo-2b-b',
      ]);
      expect(ids(const CatalogQuery(text: '  hU -- TaO  ')), ['demo-hutao-c']);
    });
    test('alias seri Inggris dan Jepang menemukan produk yang sama', () {
      expect(
        ids(const CatalogQuery(text: 'Demon Slayer')),
        ids(const CatalogQuery(text: '鬼滅の刃')),
      );
      expect(
        ids(const CatalogQuery(text: 'Nier : Automata')),
        ids(const CatalogQuery(text: 'ニーア オートマタ')),
      );
      expect(ids(const CatalogQuery(text: 'Spy x Family')), [
        'demo-anya-b',
        'demo-yor-c',
      ]);
    });
    test('browse kosong dan hasil nol tidak memakai fallback palsu', () {
      expect(searchSnapshot(snapshot, const CatalogQuery()).total, 9);
      final zero = searchSnapshot(
        snapshot,
        const CatalogQuery(text: 'kostum-yang-tidak-ada'),
      );
      expect(zero.total, 0);
      expect(zero.items, isEmpty);
    });
    test('gabungan kota, ukuran, basis dan rentang harga', () {
      expect(
        ids(
          const CatalogQuery(
            text: '2B',
            cityCode: 'id-6371',
            size: 'm',
            priceBasisDays: 3,
            minPrice: 100000,
            maxPrice: 125000,
          ),
        ),
        ['demo-2b-a'],
      );
      expect(
        ids(const CatalogQuery(cityCode: 'id-6372')).every(
          (id) =>
              snapshot
                  .store(
                    snapshot.products.firstWhere((p) => p.id == id).storeId,
                  )
                  .cityCode ==
              'id-6372',
        ),
        isTrue,
      );
      expect(
        ids(const CatalogQuery(cityCode: 'id-6303')),
        isNot(contains('demo-2b-a')),
      );
    });
    test(
      'harga memerlukan basis; durasi lain/tidak diketahui dihitung terpisah',
      () {
        expect(
          () => searchSnapshot(snapshot, const CatalogQuery(minPrice: 0)),
          throwsArgumentError,
        );
        expect(
          () => searchSnapshot(
            snapshot,
            const CatalogQuery(priceBasisDays: 5, minPrice: 0),
          ),
          throwsArgumentError,
        );
        final page = searchSnapshot(
          snapshot,
          const CatalogQuery(priceBasisDays: 3, minPrice: 0, maxPrice: 115000),
        );
        expect(page.items.map((p) => p.id), ['demo-anya-b', 'demo-tanjiro-a']);
        expect(page.total, 2);
        expect(page.excludedPriceBasisCount, 5);
        expect(
          searchSnapshot(snapshot, const CatalogQuery(priceBasisDays: 3)).total,
          9,
        );
        expect(
          () => searchSnapshot(
            snapshot,
            const CatalogQuery(
              priceBasisDays: 3,
              minPrice: 200000,
              maxPrice: 100,
            ),
          ),
          throwsArgumentError,
        );
      },
    );
    test('karakter/nama/alias mengungguli kecocokan seri; urutan stabil', () {
      final data = fixtureData();
      final weak = Map<String, dynamic>.from(
        (data['products'] as List).first as Map,
      );
      weak.addAll({
        'id': 'aaaa-series-only',
        'character': 'Pendukung',
        'name': 'Pakaian pendukung',
        'aliases': [],
        'series': '2B',
      });
      (data['products'] as List).add(weak);
      final ranked = searchSnapshot(
        CatalogSnapshot.parse(jsonEncode(data)),
        const CatalogQuery(text: '2B'),
      ).items.map((p) => p.id).toList();
      expect(ranked, ['demo-2b-a', 'demo-2b-b', 'aaaa-series-only']);
      expect(ids(const CatalogQuery()), ids(const CatalogQuery()));
    });
    test('pagination berbatas tidak menggandakan atau menghilangkan hasil', () {
      final seen = <String>[];
      String? cursor;
      do {
        final page = searchSnapshot(
          snapshot,
          const CatalogQuery(),
          cursor: cursor,
          limit: 2,
        );
        seen.addAll(page.items.map((p) => p.id));
        cursor = page.nextCursor;
      } while (cursor != null);
      expect(seen, ids(const CatalogQuery()));
      expect(seen.toSet().length, 9);
      final first = searchSnapshot(snapshot, const CatalogQuery(), limit: 2);
      expect(
        () => searchSnapshot(
          snapshot,
          const CatalogQuery(text: '2B'),
          cursor: first.nextCursor,
        ),
        throwsArgumentError,
      );
      expect(
        () => searchSnapshot(snapshot, const CatalogQuery(), limit: 25),
        throwsArgumentError,
      );
    });
  });

  group('Validasi snapshot', () {
    test(
      'fixture tidak memiliki kontak aktif dan unknown tidak menjadi nol',
      () {
        final snapshot = fixture();
        expect(
          snapshot.stores.every((s) => s.whatsapp == null && !s.contactConsent),
          isTrue,
        );
        final unknown = snapshot.products.firstWhere(
          (p) => p.id == 'demo-frieren-a',
        );
        expect(unknown.price.amountIdr, isNull);
        expect(unknown.price.durationDays, isNull);
        expect(unknown.depositIdr, isNull);
        expect(priceLabel(unknown.price), 'Harga belum diinformasikan');
      },
    );
    for (final change in <String, void Function(Map<String, dynamic>)>{
      'ID duplikat': (d) =>
          (d['products'] as List).add((d['products'] as List).first),
      'toko yatim': (d) => d['products'][0]['storeId'] = 'hilang',
      'kota tidak dikenal': (d) => d['stores'][0]['cityCode'] = 'banjar',
      'URL gambar remote': (d) =>
          d['products'][0]['imageAssets'] = ['https://example.com/x.png'],
      'path traversal gambar': (d) =>
          d['products'][0]['imageAssets'] = ['assets/event/images/../x.png'],
      'harga non integer': (d) => d['products'][0]['price']['amountIdr'] = 1.2,
      'tanggal tidak valid': (d) => d['capturedAt'] = '2026-02-30T00:00:00Z',
      'nomor fixture aktif': (d) => d['stores'][0]['whatsapp'] = '+12025550123',
      'data privat legacy': (d) => d['products'][0]['bookedDates'] = [],
      'izin nyata belum ada': (d) => d['kind'] = 'authorized',
    }.entries) {
      test('menolak ${change.key}', () {
        final data = fixtureData();
        change.value(data);
        expect(
          () => CatalogSnapshot.parse(jsonEncode(data)),
          throwsFormatException,
        );
      });
    }
  });

  group('Repository dan state', () {
    test('reset saat belum dimuat tetap menginisialisasi snapshot', () async {
      final controller = CatalogController(LocalCatalogRepository());
      await controller.resetSession();
      expect(controller.status, CatalogStatus.ready);
      expect(controller.snapshot, isNotNull);
      expect(controller.total, 9);
      controller.dispose();
    });
    test('seluruh snapshot dan gambar bisa dimuat dari bundle lokal', () async {
      final repository = LocalCatalogRepository();
      final snapshot = await repository.load();
      expect(snapshot.products.length, 9);
      for (final path in snapshot.imageAssets) {
        expect((await rootBundle.load(path)).lengthInBytes, greaterThan(100));
      }
      expect(
        (await repository.search(const CatalogQuery(text: '2B'))).total,
        2,
      );
    });
    test(
      'gagal baca, data rusak, gambar hilang dan nol hasil dibedakan',
      () async {
        final files = <String, Uint8List>{};
        final bundle = MemoryAssets(files);
        final controller = CatalogController(
          LocalCatalogRepository(bundle: bundle),
        );
        expect(controller.status, CatalogStatus.loading);
        await controller.initialize();
        expect(controller.status, CatalogStatus.failed);
        expect(controller.failure, CatalogFailure.unreadable);
        files['assets/event/catalog.json'] = Uint8List.fromList(
          utf8.encode('{broken'),
        );
        await controller.initialize();
        expect(controller.failure, CatalogFailure.invalidData);
        files['assets/event/catalog.json'] = Uint8List.fromList(
          utf8.encode(jsonEncode(fixtureData())),
        );
        await controller.initialize();
        expect(
          controller.failure,
          CatalogFailure.invalidData,
        ); // images missing
        final empty = fixtureData()..['products'] = [];
        files['assets/event/catalog.json'] = Uint8List.fromList(
          utf8.encode(jsonEncode(empty)),
        );
        await controller.initialize();
        expect(controller.status, CatalogStatus.ready);
        expect(controller.failure, isNull);
        expect(controller.total, 0);
        controller.dispose();
      },
    );
  });

  test('WhatsApp: encoding, ukuran, tanggal dan fixture nonaktif', () {
    final snapshot = fixture();
    final product = snapshot.products.first;
    final example = ContactDraft(
      product: product,
      store: snapshot.stores.first,
      illustrative: true,
    );
    expect(example.whatsappUri, isNull);
    expect(example.message, contains('[SIMULASI'));
    final store = CatalogStore(
      id: 'test',
      name: 'Toko Uji & Contoh',
      cityCode: 'id-6371',
      policies: null,
      description: null,
      verifiedAt: null,
      whatsapp: '+12025550123',
      contactConsent: true,
    );
    final draft = ContactDraft(
      product: product,
      store: store,
      illustrative: false,
      size: 'M',
      startDate: DateTime(2026, 11, 20),
      endDate: DateTime(2026, 11, 22),
    );
    final uri = draft.whatsappUri!;
    expect(uri.scheme, 'https');
    expect(uri.host, 'wa.me');
    expect(uri.path, '/12025550123');
    expect(uri.queryParameters['text'], draft.message);
    expect(draft.message, contains('Toko Uji & Contoh'));
    expect(draft.message, contains('Ukuran: M'));
    expect(draft.message, contains('20/11/2026 – 22/11/2026'));
    expect(draft.message, contains('belum booking'));
  });
}
