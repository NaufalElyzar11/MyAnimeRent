import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import '../firebase_options.dart';
import '../models/costume.dart';
import '../models/store.dart';
import '../models/rental_transaction.dart';
import '../models/review.dart';

class DatabaseService {
  final DatabaseReference _db = FirebaseDatabase.instanceFor(
    app: Firebase.app(),
    databaseURL: DefaultFirebaseOptions.databaseUrl,
  ).ref();

  // ─── Costumes ──────────────────────────────────────────────
  Future<List<Costume>> getCostumes() async {
    try {
      final snapshot = await _db.child('costumes').get().timeout(const Duration(seconds: 6));
      if (!snapshot.exists || snapshot.value == null) return [];
      final map = Map<String, dynamic>.from(snapshot.value as Map);
      return map.entries.map((e) {
        return Costume.fromMap(Map<String, dynamic>.from(e.value), e.key);
      }).toList();
    } catch (_) {
      return [];
    }
  }

  Future<Costume?> getCostumeById(String id) async {
    try {
      final snapshot = await _db.child('costumes').child(id).get().timeout(const Duration(seconds: 4));
      if (!snapshot.exists || snapshot.value == null) return null;
      return Costume.fromMap(
        Map<String, dynamic>.from(snapshot.value as Map),
        id,
      );
    } catch (_) {
      return null;
    }
  }

  Future<List<Costume>> searchCostumes(String query) async {
    final costumes = await getCostumes();
    final lowerQuery = query.toLowerCase();
    return costumes.where((c) {
      return c.name.toLowerCase().contains(lowerQuery) ||
          c.anime.toLowerCase().contains(lowerQuery);
    }).toList();
  }

  // ─── Stores ────────────────────────────────────────────────
  Future<List<Store>> getStores() async {
    try {
      final snapshot = await _db.child('stores').get().timeout(const Duration(seconds: 6));
      if (!snapshot.exists || snapshot.value == null) return [];
      final map = Map<String, dynamic>.from(snapshot.value as Map);
      return map.entries.map((e) {
        return Store.fromMap(Map<String, dynamic>.from(e.value), e.key);
      }).toList();
    } catch (_) {
      return [];
    }
  }

  Future<Store?> getStoreById(String id) async {
    try {
      final snapshot = await _db.child('stores').child(id).get().timeout(const Duration(seconds: 4));
      if (!snapshot.exists || snapshot.value == null) return null;
      return Store.fromMap(
        Map<String, dynamic>.from(snapshot.value as Map),
        id,
      );
    } catch (_) {
      return null;
    }
  }

  // ─── Rentals ───────────────────────────────────────────────
  Future<List<RentalTransaction>> getRentalsForUser(String userId) async {
    try {
      final snapshot = await _db
          .child('rentals')
          .orderByChild('userId')
          .equalTo(userId)
          .get()
          .timeout(const Duration(seconds: 4));
      if (!snapshot.exists || snapshot.value == null) return [];
      final map = Map<String, dynamic>.from(snapshot.value as Map);
      return map.entries.map((e) {
        return RentalTransaction.fromMap(Map<String, dynamic>.from(e.value), e.key);
      }).toList();
    } catch (_) {
      // Fallback in case indexed query times out
      try {
        final snapshot = await _db.child('rentals').get().timeout(const Duration(seconds: 4));
        if (!snapshot.exists || snapshot.value == null) return [];
        final map = Map<String, dynamic>.from(snapshot.value as Map);
        return map.entries
            .map((e) => RentalTransaction.fromMap(Map<String, dynamic>.from(e.value), e.key))
            .where((r) => r.userId == userId)
            .toList();
      } catch (_) {
        return [];
      }
    }
  }

  Future<void> createRental(RentalTransaction rental) async {
    final ref = _db.child('rentals').push();
    await ref.set(rental.toMap());

    // Update booked dates on costume directly at /costumes/$costumeId/bookedDates
    // Firebase security rules explicitly permit write on bookedDates for authenticated users.
    try {
      final bookedDatesRef = _db
          .child('costumes')
          .child(rental.costumeId)
          .child('bookedDates');
      final bookedSnap =
          await bookedDatesRef.get().timeout(const Duration(seconds: 4));

      final currentBooked = <String>{};
      if (bookedSnap.exists && bookedSnap.value != null) {
        final val = bookedSnap.value;
        if (val is List) {
          currentBooked
              .addAll(val.where((e) => e != null).map((e) => e.toString()));
        } else if (val is Map) {
          currentBooked
              .addAll(val.values.where((e) => e != null).map((e) => e.toString()));
        }
      }

      var curr = DateTime(
          rental.startDate.year, rental.startDate.month, rental.startDate.day);
      final end = DateTime(
          rental.endDate.year, rental.endDate.month, rental.endDate.day);
      while (!curr.isAfter(end)) {
        final dateStr =
            "${curr.year.toString().padLeft(4, '0')}-${curr.month.toString().padLeft(2, '0')}-${curr.day.toString().padLeft(2, '0')}";
        currentBooked.add(dateStr);
        curr = curr.add(const Duration(days: 1));
      }

      final sortedDates = currentBooked.toList()..sort();
      await bookedDatesRef.set(sortedDates);
    } catch (_) {}
  }

  // ─── Wishlist ──────────────────────────────────────────────
  Future<List<String>> getWishlist(String userId) async {
    try {
      final snapshot = await _db
          .child('users')
          .child(userId)
          .child('wishlist')
          .get()
          .timeout(const Duration(seconds: 4));
      if (!snapshot.exists || snapshot.value == null) return [];
      final map = Map<String, dynamic>.from(snapshot.value as Map);
      return map.keys.toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> addToWishlist(String userId, String costumeId) async {
    try {
      await _db
          .child('users')
          .child(userId)
          .child('wishlist')
          .child(costumeId)
          .set(true);
    } catch (_) {}
  }

  Future<void> removeFromWishlist(String userId, String costumeId) async {
    try {
      await _db
          .child('users')
          .child(userId)
          .child('wishlist')
          .child(costumeId)
          .remove();
    } catch (_) {}
  }

  Future<bool> isWishlisted(String userId, String costumeId) async {
    try {
      final snapshot = await _db
          .child('users')
          .child(userId)
          .child('wishlist')
          .child(costumeId)
          .get()
          .timeout(const Duration(seconds: 3));
      return snapshot.exists;
    } catch (_) {
      return false;
    }
  }

  // ─── Reviews ───────────────────────────────────────────────
  Future<List<Review>> getReviewsForRental(String rentalId) async {
    try {
      final snapshot = await _db
          .child('reviews')
          .orderByChild('rentalId')
          .equalTo(rentalId)
          .get()
          .timeout(const Duration(seconds: 3));
      if (!snapshot.exists || snapshot.value == null) return [];
      final map = Map<String, dynamic>.from(snapshot.value as Map);
      return map.entries.map((e) {
        return Review.fromMap(Map<String, dynamic>.from(e.value), e.key);
      }).toList();
    } catch (_) {
      try {
        final snapshot = await _db.child('reviews').get().timeout(const Duration(seconds: 3));
        if (!snapshot.exists || snapshot.value == null) return [];
        final map = Map<String, dynamic>.from(snapshot.value as Map);
        return map.entries
            .map((e) => Review.fromMap(Map<String, dynamic>.from(e.value), e.key))
            .where((r) => r.rentalId == rentalId)
            .toList();
      } catch (_) {
        return [];
      }
    }
  }

  // ─── Reviews ───────────────────────────────────────────────
  Future<List<Review>> getReviewsForCostume(String costumeId) async {
    try {
      final snapshot = await _db
          .child('reviews')
          .orderByChild('costumeId')
          .equalTo(costumeId)
          .get()
          .timeout(const Duration(seconds: 3));
      if (!snapshot.exists || snapshot.value == null) return [];
      final map = Map<String, dynamic>.from(snapshot.value as Map);
      return map.entries.map((e) {
        return Review.fromMap(Map<String, dynamic>.from(e.value), e.key);
      }).toList();
    } catch (_) {
      // Fallback if indexed query times out on server
      try {
        final snapshot = await _db.child('reviews').get().timeout(const Duration(seconds: 3));
        if (!snapshot.exists || snapshot.value == null) return [];
        final map = Map<String, dynamic>.from(snapshot.value as Map);
        return map.entries
            .map((e) => Review.fromMap(Map<String, dynamic>.from(e.value), e.key))
            .where((r) => r.costumeId == costumeId)
            .toList();
      } catch (_) {
        return [];
      }
    }
  }

  Future<void> createReview(Review review) async {
    final ref = _db.child('reviews').push();
    await ref.set(review.toMap());
  }

  Future<void> updateReview(String reviewId, Map<String, dynamic> data) async {
    await _db.child('reviews').child(reviewId).update(data);
  }

  Future<void> deleteReview(String reviewId) async {
    await _db.child('reviews').child(reviewId).remove();
  }
}
