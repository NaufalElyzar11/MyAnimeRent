import 'dart:io';

import 'package:myanimerent/event/catalog.dart';
import 'package:myanimerent/event/image_validation.dart';

/// Run from the Flutter root; never reads Firebase or imports Flutter services.
Future<void> main(List<String> arguments) async {
  final ready = arguments.contains('--event-ready');
  final paths = arguments.where((a) => a != '--event-ready').toList();
  if (paths.length > 1) {
    stderr.writeln(
      'Penggunaan: dart run tool/validate_event_catalog.dart [snapshot.json] [--event-ready]',
    );
    exitCode = 2;
    return;
  }
  try {
    final snapshot = CatalogSnapshot.parse(
      await File(paths.isEmpty ? 'assets/event/catalog.json' : paths.single)
          .readAsString(),
    );
    for (final path in snapshot.imageAssets) {
      if (!isCatalogImage(await File(path).readAsBytes())) {
        throw FormatException('Gambar tidak valid: $path');
      }
    }
    stdout.writeln(
      'VALID: ${snapshot.revision}; ${snapshot.stores.length} toko; ${snapshot.products.length} kostum; ${snapshot.imageAssets.length} gambar lokal.',
    );
    stdout.writeln(
      'Jenis: ${snapshot.illustrative ? 'ILUSTRATIF — harga simulasi, kontak nonaktif' : 'AUTHORIZED — izin harus tetap ditinjau pengelola'}.',
    );
    if (ready) {
      final issues = <String>[
        if (snapshot.illustrative) 'Dataset masih ilustratif.',
        if (snapshot.stores.length < 2)
          'Perlu sedikitnya dua toko berizin untuk uji lintas toko.',
        for (final store in snapshot.stores) ...[
          if (!snapshot.products.any((p) => p.storeId == store.id))
            'Toko ${store.id} belum mempunyai produk.',
          if (!store.contactConsent || store.whatsapp == null)
            'Kontak bisnis berizin ${store.id} belum lengkap.',
        ],
        for (final product in snapshot.products)
          if (product.sizes.isEmpty ||
              product.price.amountIdr == null ||
              product.price.durationDays == null)
            'Ukuran/harga/periode ${product.id} belum lengkap.',
      ];
      if (issues.isNotEmpty) {
        stderr.writeln('BELUM SIAP UJI KATALOG NYATA:\n${issues.join('\n')}');
        exitCode = 2;
      } else {
        stdout.writeln(
          'Gerbang struktur katalog nyata lulus. Tinjau bukti izin, akurasi dan kemutakhiran bersama toko sebelum event.',
        );
      }
    }
  } on FileSystemException catch (e) {
    stderr.writeln('TIDAK VALID: berkas lokal tidak dapat dibaca: ${e.path}');
    exitCode = 1;
  } on FormatException catch (e) {
    stderr.writeln('TIDAK VALID: ${e.message}');
    exitCode = 1;
  }
}
