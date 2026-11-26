import 'package:flutter/material.dart';

import '../models/costume.dart';
import '../models/store.dart';
import '../services/database_service.dart';

/// Katalog publik (tanpa login). Kartu dari `search_products`, detail diambil saat dibuka.
class CostumeProvider extends ChangeNotifier {
  final DatabaseService _dbService = DatabaseService();

  List<Costume> _costumes = [];
  List<Store> _stores = [];
  final Map<String, Costume> _details = {};
  bool _isLoading = false;
  String? _error;

  List<Costume> get costumes => _costumes;
  List<Store> get stores => _stores;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Map<String, List<Costume>> get costumesByAnime {
    final map = <String, List<Costume>>{};
    for (final costume in _costumes) {
      final key = costume.anime.trim().toLowerCase();
      map.putIfAbsent(key, () => []).add(costume);
    }
    return map;
  }

  List<Costume> get popularCostumes => _costumes;

  Future<void> loadData({bool force = false}) async {
    if (_costumes.isNotEmpty && !force) return;
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      final results = await Future.wait([_dbService.getCostumes(), _dbService.getStores()]);
      _costumes = results[0] as List<Costume>;
      _stores = results[1] as List<Store>;
    } catch (e) {
      _error = e.toString();
    }
    _isLoading = false;
    notifyListeners();
  }

  /// Detail lengkap (deskripsi, varian, harga, foto). Selalu dari server agar harga terbaru.
  Future<Costume?> getCostumeById(String id, {bool refresh = false}) async {
    if (!refresh && _details.containsKey(id)) return _details[id];
    final costume = await _dbService.getCostumeById(id);
    if (costume != null) _details[id] = costume;
    return costume;
  }

  /// Profil toko publik (kebijakan, kontak bila disetujui toko).
  Future<Store?> getStoreById(String slug) async {
    final fromList = _stores.where((s) => s.id == slug).firstOrNull;
    final detail = await _dbService.getStoreBySlug(slug);
    if (detail == null) return fromList;
    return detail.withImage(fromList?.imageUrl ?? '');
  }

  Future<List<Costume>> loadStoreCostumes(String slug) => _dbService.getCostumes(storeSlug: slug);

  Future<List<Costume>> search(String query) => _dbService.searchProducts(query: query);

  List<Costume> getCostumesForStore(String storeId) => _costumes.where((c) => c.storeId == storeId).toList();

  List<Costume> getCostumesForAnime(String anime) => _costumes
      .where((c) => c.anime.trim().toLowerCase() == anime.trim().toLowerCase())
      .toList();
}
