import 'package:flutter/material.dart';
import '../models/costume.dart';
import '../models/store.dart';
import '../services/database_service.dart';

class CostumeProvider extends ChangeNotifier {
  final DatabaseService _dbService = DatabaseService();

  List<Costume> _costumes = [];
  List<Store> _stores = [];
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
    // If we already have data, don't show full-screen blocking spinner
    if (_costumes.isEmpty || force) {
      _isLoading = true;
      _error = null;
      notifyListeners();
    }

    try {
      final results = await Future.wait([
        _dbService.getCostumes(),
        _dbService.getStores(),
      ]);
      _costumes = results[0] as List<Costume>;
      _stores = results[1] as List<Store>;
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<Costume?> getCostumeById(String id) async {
    // Check in-memory cache first for instant response
    try {
      final cached = _costumes.firstWhere((c) => c.id == id);
      return cached;
    } catch (_) {}
    return await _dbService.getCostumeById(id);
  }

  Future<Store?> getStoreById(String id) async {
    // Check in-memory cache first for instant response
    try {
      final cached = _stores.firstWhere((s) => s.id == id);
      return cached;
    } catch (_) {}
    return await _dbService.getStoreById(id);
  }

  List<Costume> getCostumesForStore(String storeId) {
    return _costumes.where((c) => c.storeId == storeId).toList();
  }

  List<Costume> getCostumesForAnime(String anime) {
    return _costumes
        .where((c) => c.anime.trim().toLowerCase() == anime.trim().toLowerCase())
        .toList();
  }
}
