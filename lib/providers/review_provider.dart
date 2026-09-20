import 'package:flutter/material.dart';
import '../models/review.dart';
import '../services/database_service.dart';
import '../services/auth_service.dart';

class ReviewProvider extends ChangeNotifier {
  final DatabaseService _dbService = DatabaseService();
  final AuthService _authService = AuthService();

  List<Review> _reviews = [];
  List<Review> get reviews => _reviews;

  Future<void> loadReviewsForCostume(String costumeId) async {
    _reviews = await _dbService.getReviewsForCostume(costumeId);
    notifyListeners();
  }

  Future<void> createReview({
    required String costumeId,
    required String storeId,
    required String rentalId,
    required String text,
    required double costumeRating,
    required double storeRating,
  }) async {
    final user = _authService.currentUser;
    if (user == null) return;

    final appUser = await _authService.getCurrentAppUser();

    final review = Review(
      id: '',
      userId: user.uid,
      costumeId: costumeId,
      storeId: storeId,
      rentalId: rentalId,
      text: text,
      costumeRating: costumeRating,
      storeRating: storeRating,
      userPhotoUrl: appUser?.profileImageUrl,
      userName: appUser?.name ?? 'Anonymous',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    await _dbService.createReview(review);
    await loadReviewsForCostume(costumeId);
  }

  Future<void> updateReview({
    required String reviewId,
    required String costumeId,
    required String text,
    required double costumeRating,
    required double storeRating,
  }) async {
    await _dbService.updateReview(reviewId, {
      'text': text,
      'costumeRating': costumeRating,
      'storeRating': storeRating,
      'updatedAt': DateTime.now().toIso8601String(),
    });
    await loadReviewsForCostume(costumeId);
  }

  Future<void> deleteReview(String reviewId, String costumeId) async {
    await _dbService.deleteReview(reviewId);
    await loadReviewsForCostume(costumeId);
  }
}
