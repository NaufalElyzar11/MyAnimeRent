// Tes model kelola katalog & profil toko (bentuk JSON sama dengan migrasi 20261126000200_store_catalog_api.sql).
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:myanimerent/models/store_catalog.dart';
import 'package:myanimerent/services/store_catalog_service.dart';

String img(String path) => 'https://cdn.uji/$path';

void main() {
  test('ringkasan listing: kekurangan untuk terbit', () {
    final p = StoreProductSummary.fromJson({
      'product_id': 'p1',
      'title': 'Frieren • Jubah penyihir',
      'status': 'draft',
      'revision': 4,
      'sizes': ['S', 'M'],
      'image_count': 0,
      'missing_for_publish': ['image', 'publication_consent'],
    }, img);
    expect(p.isDraft, isTrue);
    expect(p.readyToPublish, isFalse);
    expect(p.coverUrl, isEmpty);
    expect(missingText(p.missing), 'Minimal 1 foto, Izin tampil publik');
  });

  test('isi form edit: harga, ukuran aktif, foto', () {
    final d = StoreProductDetail.fromJson({
      'product_id': 'p1',
      'store_id': 's1',
      'title': '2B',
      'status': 'published',
      'revision': 7,
      'category': 'costume',
      'package_contents': ['Dress', 'Wig'],
      'aliases': ['YoRHa 2B'],
      'variants': [
        {'id': 'v1', 'size_label': 'S', 'measurements_cm': {'chest': 84}, 'enabled': true},
        {'id': 'v2', 'size_label': 'XL', 'measurements_cm': {}, 'enabled': false},
      ],
      'price': {
        'amount_idr': 120000,
        'duration_days': 3,
        'extra_day_idr': null,
        'deposit_idr': 50000,
        'buffer_before_days': 0,
        'buffer_after_days': 1,
      },
      'images': [
        {'image_id': 'i1', 'storage_path': 'demo/2b.png', 'position': 1},
      ],
      'missing_for_publish': [],
    }, img);
    expect(d.activeVariants.map((v) => v.sizeLabel), ['S']);
    expect(d.activeVariants.single.toJson(), {
      'id': 'v1',
      'size_label': 'S',
      'measurements_cm': {'chest': 84},
      'enabled': true,
    });
    expect(d.price!.amountIdr, 120000);
    expect(d.images.single.url, 'https://cdn.uji/demo/2b.png');
    expect(EditableVariant(sizeLabel: 'M').toJson(), {'size_label': 'M', 'enabled': true});
  });

  test('harga dianggap sama bila tidak ada yang berubah', () {
    final a = EditablePrice(amountIdr: 100000, durationDays: 3, depositIdr: 0);
    expect(a.sameAs(EditablePrice(amountIdr: 100000, durationDays: 3, depositIdr: 0)), isTrue);
    expect(a.sameAs(EditablePrice(amountIdr: 110000, durationDays: 3, depositIdr: 0)), isFalse);
    expect(a.sameAs(null), isFalse);
  });

  test('profil toko', () {
    final s = StoreProfile.fromJson({
      'store_id': 's1',
      'slug': 'toko-a',
      'name': 'Toko A',
      'status': 'draft',
      'revision': 2,
      'city_code': 'id-6371',
      'whatsapp_e164': '+6281234567890',
      'contact_public': true,
      'is_owner': true,
      'published_products': 0,
    });
    expect(s.isPublished, isFalse);
    expect(s.isOwner, isTrue);
    expect(s.whatsapp, '+6281234567890');
  });

  test('jenis foto dikenali dari isi file, bukan nama', () {
    expect(detectImageType(Uint8List.fromList([0xFF, 0xD8, 0xFF, 0xE0])), 'image/jpeg');
    expect(detectImageType(Uint8List.fromList([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A])), 'image/png');
    expect(
      detectImageType(Uint8List.fromList('RIFF\x00\x00\x00\x00WEBP'.codeUnits)),
      'image/webp',
    );
    expect(detectImageType(Uint8List.fromList('ftypheic'.codeUnits)), isNull);
  });
}
