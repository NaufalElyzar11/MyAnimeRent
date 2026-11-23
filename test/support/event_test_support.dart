import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:myanimerent/event/catalog.dart';
import 'package:myanimerent/event/catalog_repository.dart';
import 'package:myanimerent/event/catalog_search.dart';
import 'package:myanimerent/event/contact_service.dart';

class SnapshotRepository implements CatalogRepository {
  SnapshotRepository(this.snapshot);
  final CatalogSnapshot snapshot;
  @override
  Future<CatalogSnapshot> load() async => snapshot;
  @override
  Future<CatalogPage> search(
    CatalogQuery query, {
    String? cursor,
    int limit = 12,
  }) async => searchSnapshot(snapshot, query, cursor: cursor, limit: limit);
}

class FailedRepository implements CatalogRepository {
  FailedRepository(this.failure);
  final CatalogFailure failure;
  @override
  Future<CatalogSnapshot> load() async => throw CatalogLoadException(failure);
  @override
  Future<CatalogPage> search(
    CatalogQuery query, {
    String? cursor,
    int limit = 12,
  }) async => throw CatalogLoadException(failure);
}

class RecordingContactGateway implements ContactGateway {
  final List<Uri> opened = [];
  @override
  Future<bool> open(Uri uri) async {
    opened.add(uri);
    return false;
  }
}

/// Reserved NANP fictional number; never opened externally in tests.
Future<CatalogSnapshot> authorizedTestSnapshot() async {
  final data = jsonDecode(
    await rootBundle.loadString('assets/event/catalog.json'),
  ) as Map<String, dynamic>;
  data['kind'] = 'authorized';
  for (final s in data['stores'] as List) {
    (s as Map<String, dynamic>).addAll({
      'publicationConsent': true,
      'consentReference': 'test-only-not-real-consent',
      'verifiedAt': '2026-11-12T00:00:00Z',
      'whatsapp': '+12025550123',
      'contactConsent': true,
    });
  }
  for (final p in data['products'] as List) {
    (p as Map<String, dynamic>).addAll({
      'publicationConsent': true,
      'consentReference': 'test-only-not-real-consent',
      'verifiedAt': '2026-11-12T00:00:00Z',
    });
  }
  return CatalogSnapshot.parse(jsonEncode(data));
}
