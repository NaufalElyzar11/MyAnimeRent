import 'package:flutter/material.dart';

import '../models/rental_request.dart';
import '../models/store_admin.dart';
import '../services/store_admin_service.dart';

/// Filter kotak permintaan toko.
enum RequestFilter { needsAnswer, confirmed, closed, all }

extension RequestFilterX on RequestFilter {
  String get label => switch (this) {
        RequestFilter.needsAnswer => 'Perlu dijawab',
        RequestFilter.confirmed => 'Dikonfirmasi',
        RequestFilter.closed => 'Selesai',
        RequestFilter.all => 'Semua',
      };

  bool matches(StoreRequest r) => switch (this) {
        RequestFilter.needsAnswer => r.status.isOpen,
        RequestFilter.confirmed => r.status == RequestStatus.accepted,
        RequestFilter.closed => !r.status.isOpen && r.status != RequestStatus.accepted,
        RequestFilter.all => true,
      };
}

/// Mode "Toko Saya": toko milik pengguna, toko yang sedang dibuka, dan kotak permintaannya.
class StoreAdminProvider extends ChangeNotifier {
  final StoreAdminService _service = StoreAdminService();

  List<MyStore> _stores = [];
  String? _selectedId;
  List<StoreRequest> _requests = [];
  RequestFilter _filter = RequestFilter.needsAnswer;
  bool _loadingStores = false;
  bool _loadingRequests = false;
  String? _error;

  List<MyStore> get stores => _stores;
  bool get hasStores => _stores.isNotEmpty;
  bool get loadingStores => _loadingStores;
  bool get loadingRequests => _loadingRequests;
  String? get error => _error;
  RequestFilter get filter => _filter;

  MyStore? get selected {
    for (final s in _stores) {
      if (s.id == _selectedId) return s;
    }
    return _stores.isEmpty ? null : _stores.first;
  }

  List<StoreRequest> get requests => _requests.where(_filter.matches).toList();
  int get openCount => _requests.where((r) => r.status.isOpen).length;
  int countFor(RequestFilter f) => _requests.where(f.matches).length;

  /// Dipanggil saat login. Pengguna tanpa toko tidak melihat tab Toko.
  Future<void> loadStores() async {
    _loadingStores = true;
    notifyListeners();
    try {
      _stores = await _service.listMyStores();
      if (_stores.every((s) => s.id != _selectedId)) {
        _selectedId = _stores.isEmpty ? null : _stores.first.id;
      }
      _error = null;
    } catch (e) {
      _error = e.toString();
    }
    _loadingStores = false;
    notifyListeners();
    if (selected?.canOrders == true) await loadRequests();
  }

  Future<void> select(String storeId) async {
    if (storeId == _selectedId) return;
    _selectedId = storeId;
    _requests = [];
    notifyListeners();
    await loadRequests();
  }

  void setFilter(RequestFilter f) {
    _filter = f;
    notifyListeners();
  }

  Future<void> loadRequests() async {
    final store = selected;
    if (store == null || !store.canOrders) return;
    _loadingRequests = true;
    notifyListeners();
    try {
      _requests = await _service.listRequests(store.id);
      _error = null;
    } catch (e) {
      _error = e.toString();
    }
    _loadingRequests = false;
    notifyListeners();
  }

  void clear() {
    _stores = [];
    _selectedId = null;
    _requests = [];
    _error = null;
    _filter = RequestFilter.needsAnswer;
    notifyListeners();
  }
}
