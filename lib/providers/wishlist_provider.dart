import 'package:flutter/material.dart';

import '../models/costume.dart';
import '../services/auth_service.dart';
import '../services/database_service.dart';

/// Wishlist milik akun (tabel `wishlists`, RLS: hanya pemilik). Sama di app dan website.
class WishlistProvider extends ChangeNotifier {
  final DatabaseService _dbService = DatabaseService();
  final AuthService _authService = AuthService();

  List<Costume> _wishlistItems = [];
  final Set<String> _ids = {};
  bool _isLoading = false;
  String? _error;

  List<Costume> get wishlistItems => _wishlistItems;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get canUse => _authService.currentUser != null;

  bool isItemInWishlist(String costumeId) => _ids.contains(costumeId);

  Future<void> loadWishlist() async {
    final user = _authService.currentUser;
    if (user == null) return;
    _isLoading = true;
    notifyListeners();
    try {
      final ids = await _dbService.getWishlistIds(user.id);
      _ids
        ..clear()
        ..addAll(ids);
      _wishlistItems = await _dbService.getCostumesByIds(ids);
      _error = null;
    } catch (e) {
      _error = e.toString();
    }
    _isLoading = false;
    notifyListeners();
  }

  /// Mengembalikan status baru; null bila belum login.
  Future<bool?> toggleWishlist(String costumeId) async {
    final user = _authService.currentUser;
    if (user == null) return null;
    final wasIn = _ids.contains(costumeId);
    // Perbarui tampilan dulu, kembalikan bila server menolak.
    wasIn ? _ids.remove(costumeId) : _ids.add(costumeId);
    notifyListeners();
    try {
      if (wasIn) {
        await _dbService.removeFromWishlist(user.id, costumeId);
        _wishlistItems.removeWhere((c) => c.id == costumeId);
      } else {
        await _dbService.addToWishlist(user.id, costumeId);
        final added = await _dbService.getCostumesByIds([costumeId]);
        _wishlistItems = [...added, ..._wishlistItems.where((c) => c.id != costumeId)];
      }
      notifyListeners();
      return !wasIn;
    } catch (e) {
      wasIn ? _ids.add(costumeId) : _ids.remove(costumeId);
      _error = e.toString();
      notifyListeners();
      return wasIn;
    }
  }

  Future<bool> isWishlisted(String costumeId) async => _ids.contains(costumeId);

  void clear() {
    _ids.clear();
    _wishlistItems = [];
    notifyListeners();
  }
}
