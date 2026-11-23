import 'package:flutter/services.dart';

import 'catalog.dart';
import 'catalog_search.dart';
import 'image_validation.dart';

enum CatalogFailure { unreadable, invalidData }

class CatalogLoadException implements Exception {
  const CatalogLoadException(this.failure);
  final CatalogFailure failure;
}

abstract interface class CatalogRepository {
  Future<CatalogSnapshot> load();
  Future<CatalogPage> search(
    CatalogQuery query, {
    String? cursor,
    int limit = 12,
  });
}

class LocalCatalogRepository implements CatalogRepository {
  LocalCatalogRepository({
    AssetBundle? bundle,
    this.assetPath = const String.fromEnvironment(
      'EVENT_CATALOG_ASSET',
      defaultValue: 'assets/event/catalog.json',
    ),
  }) : _bundle = bundle ?? rootBundle;

  final AssetBundle _bundle;
  final String assetPath;
  CatalogSnapshot? _snapshot;

  @override
  Future<CatalogSnapshot> load() async {
    if (_snapshot != null) return _snapshot!;
    String source;
    try {
      source = await _bundle.loadString(assetPath, cache: false);
    } catch (_) {
      throw const CatalogLoadException(CatalogFailure.unreadable);
    }
    CatalogSnapshot snapshot;
    try {
      snapshot = CatalogSnapshot.parse(source);
    } catch (_) {
      throw const CatalogLoadException(CatalogFailure.invalidData);
    }
    // Validate every referenced image before publishing the snapshot to the UI.
    try {
      for (final image in snapshot.imageAssets) {
        final data = await _bundle.load(image);
        final bytes = data.buffer.asUint8List(
          data.offsetInBytes,
          data.lengthInBytes,
        );
        if (!isCatalogImage(bytes)) {
          throw const FormatException('Gambar tidak valid');
        }
      }
    } catch (_) {
      throw const CatalogLoadException(CatalogFailure.invalidData);
    }
    _snapshot = snapshot;
    return snapshot;
  }

  @override
  Future<CatalogPage> search(
    CatalogQuery query, {
    String? cursor,
    int limit = 12,
  }) async => searchSnapshot(await load(), query, cursor: cursor, limit: limit);
}
