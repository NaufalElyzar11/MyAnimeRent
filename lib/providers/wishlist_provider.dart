import 'package:flutter/material.dart';
import '../models/costume.dart';
import '../services/database_service.dart';
import '../services/auth_service.dart';

class WishlistProvider extends ChangeNotifier {
  final DatabaseService _dbService = DatabaseService();
  final AuthService _authService = AuthService();

  List<Costume> _wishlistItems = [];
  bool _isLoading = false;
  String? _error;

  List<Costume> get wishlistItems => _wishlistItems;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> loadWishlist() async {
    final user = _authService.currentUser;
    if (user == null) return;

    _isLoading = true;
    notifyListeners();

    try {
      final costumeIds = await _dbService.getWishlist(user.uid);
      final items = <Costume>[];
      for (final id in costumeIds) {
        final costume = await _dbService.getCostumeById(id);
        if (costume != null) items.add(costume);
      }
      _wishlistItems = items;
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> toggleWishlist(String costumeId) async {
    final user = _authService.currentUser;
    if (user == null) return false;

    final isAlready = await _dbService.isWishlisted(user.uid, costumeId);
    if (isAlready) {
      await _dbService.removeFromWishlist(user.uid, costumeId);
      _wishlistItems.removeWhere((item) => item.id == costumeId);
      notifyListeners();
      return false;
    } else {
      await _dbService.addToWishlist(user.uid, costumeId);
      final costume = await _dbService.getCostumeById(costumeId);
      if (costume != null && !_wishlistItems.any((c) => c.id == costumeId)) {
        _wishlistItems.add(costume);
      }
      notifyListeners();
      return true;
    }
  }

  Future<bool> isWishlisted(String costumeId) async {
    final user = _authService.currentUser;
    if (user == null) return false;
    return await _dbService.isWishlisted(user.uid, costumeId);
  }
}
