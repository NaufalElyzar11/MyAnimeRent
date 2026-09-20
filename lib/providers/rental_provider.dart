import 'package:flutter/material.dart';
import '../models/rental_transaction.dart';
import '../models/costume.dart';
import '../services/database_service.dart';
import '../services/auth_service.dart';

class RentalHistoryItem {
  final String id;
  final Costume costume;
  final DateTime startDate;
  final DateTime endDate;
  final double totalPrice;
  final RentalStatus status;
  final String? size;

  RentalHistoryItem({
    required this.id,
    required this.costume,
    required this.startDate,
    required this.endDate,
    required this.totalPrice,
    required this.status,
    this.size,
  });
}

class RentalProvider extends ChangeNotifier {
  final DatabaseService _dbService = DatabaseService();
  final AuthService _authService = AuthService();

  List<RentalHistoryItem> _rentals = [];
  bool _isLoading = false;
  String? _message;
  final Set<String> _reviewedRentals = {};

  List<RentalHistoryItem> get rentals => _rentals;
  bool get isLoading => _isLoading;
  String? get message => _message;
  Set<String> get reviewedRentals => _reviewedRentals;

  bool isReviewed(RentalHistoryItem item) {
    return _reviewedRentals.contains(item.id) ||
        _reviewedRentals.contains(item.endDate.toIso8601String());
  }

  void markAsReviewed(String key) {
    _reviewedRentals.add(key);
    notifyListeners();
  }

  Future<void> loadRentalHistory() async {
    final user = _authService.currentUser;
    if (user == null) return;

    _isLoading = true;
    notifyListeners();

    try {
      final transactions = await _dbService.getRentalsForUser(user.uid);
      // Sort newest first
      transactions.sort((a, b) => b.createdAt.compareTo(a.createdAt));

      final results = await Future.wait(transactions.map((tx) async {
        final costumeFuture = _dbService.getCostumeById(tx.costumeId);
        final reviewFuture =
            _dbService.getReviewsForRental(tx.endDate.toIso8601String());
        final costume = await costumeFuture;
        final existingReviews = await reviewFuture;

        if (costume == null) return null;

        if (existingReviews.isNotEmpty) {
          _reviewedRentals.add(tx.endDate.toIso8601String());
          if (tx.id.isNotEmpty) _reviewedRentals.add(tx.id);
        }

        return RentalHistoryItem(
          id: tx.id,
          costume: costume,
          startDate: tx.startDate,
          endDate: tx.endDate,
          totalPrice: tx.totalPrice,
          status: tx.status,
          size: tx.size,
        );
      }));

      _rentals = results.whereType<RentalHistoryItem>().toList();
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _isLoading = false;
      _message = e.toString();
      notifyListeners();
    }
  }

  Future<bool> createRental({
    required String costumeId,
    required DateTime startDate,
    required DateTime endDate,
    required double totalPrice,
    String? size,
  }) async {
    final user = _authService.currentUser;
    if (user == null) {
      _message = 'Please login first';
      notifyListeners();
      return false;
    }

    try {
      final rental = RentalTransaction(
        id: '',
        userId: user.uid,
        costumeId: costumeId,
        startDate: startDate,
        endDate: endDate,
        totalPrice: totalPrice,
        status: RentalStatus.pending,
        size: size,
      );
      await _dbService.createRental(rental);
      _message = 'Rental created successfully!';
      notifyListeners();
      return true;
    } catch (e) {
      _message = 'Failed to create rental: $e';
      notifyListeners();
      return false;
    }
  }

  void clearMessage() {
    _message = null;
    notifyListeners();
  }
}
