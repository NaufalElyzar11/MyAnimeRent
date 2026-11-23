import 'package:flutter/foundation.dart';

import 'catalog.dart';
import 'catalog_repository.dart';
import 'catalog_search.dart';

enum CatalogStatus { loading, ready, failed }

class CatalogController extends ChangeNotifier {
  CatalogController(this.repository);
  final CatalogRepository repository;
  CatalogStatus status = CatalogStatus.loading;
  CatalogFailure? failure;
  CatalogSnapshot? snapshot;
  CatalogQuery query = const CatalogQuery();
  List<CatalogProduct> items = const [];
  int total = 0;
  int excludedPriceBasisCount = 0;
  String? nextCursor;
  bool searching = false;
  int session = 0;
  final Set<String> _favoriteIds = {};

  bool isFavorite(String id) => _favoriteIds.contains(id);
  List<CatalogProduct> get favorites =>
      snapshot?.products.where((p) => _favoriteIds.contains(p.id)).toList() ??
      [];

  void toggleFavorite(String id) {
    if (!(snapshot?.products.any((p) => p.id == id) ?? false)) return;
    if (!_favoriteIds.remove(id)) _favoriteIds.add(id);
    _notify();
  }

  int _request = 0;
  bool _disposed = false;

  Future<void> resetSession() async {
    session++;
    _favoriteIds.clear();
    query = const CatalogQuery();
    if (snapshot == null) {
      await initialize();
    } else {
      await setQuery(query);
    }
  }

  Future<void> initialize() async {
    status = CatalogStatus.loading;
    failure = null;
    _notify();
    try {
      snapshot = await repository.load();
      await setQuery(query);
    } on CatalogLoadException catch (e) {
      failure = e.failure;
      status = CatalogStatus.failed;
      _notify();
    } catch (_) {
      failure = CatalogFailure.unreadable;
      status = CatalogStatus.failed;
      _notify();
    }
  }

  Future<void> setQuery(CatalogQuery value, {bool more = false}) async {
    final request = ++_request;
    query = value;
    searching = true;
    _notify();
    try {
      final page = await repository.search(
        value,
        cursor: more ? nextCursor : null,
      );
      if (_disposed || request != _request) return;
      items = more ? [...items, ...page.items] : page.items;
      total = page.total;
      excludedPriceBasisCount = page.excludedPriceBasisCount;
      nextCursor = page.nextCursor;
      status = CatalogStatus.ready;
      failure = null;
    } on CatalogLoadException catch (e) {
      if (_disposed || request != _request) return;
      failure = e.failure;
      status = CatalogStatus.failed;
    } catch (_) {
      if (_disposed || request != _request) return;
      failure = CatalogFailure.unreadable;
      status = CatalogStatus.failed;
    } finally {
      if (!_disposed && request == _request) {
        searching = false;
        _notify();
      }
    }
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
