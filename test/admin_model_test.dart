import 'package:flutter_test/flutter_test.dart';
import 'package:myanimerent/models/user.dart';
import 'package:myanimerent/models/costume.dart';
import 'package:myanimerent/models/store.dart';
import 'package:myanimerent/models/rental_transaction.dart';

void main() {
  group('Admin & Models Unit Tests', () {
    test('AppUser handles role and isAdmin correctly', () {
      final regularUser = AppUser(
        id: 'u1',
        email: 'user@test.com',
        name: 'Regular User',
      );
      expect(regularUser.role, 'user');
      expect(regularUser.isAdmin, isFalse);

      final adminUser = AppUser(
        id: 'u2',
        email: 'admin@test.com',
        name: 'Admin Boss',
        role: 'admin',
      );
      expect(adminUser.role, 'admin');
      expect(adminUser.isAdmin, isTrue);

      final fromMapUser = AppUser.fromMap({
        'email': 'admin2@test.com',
        'name': 'Admin Two',
        'role': 'Admin',
      }, 'u3');
      expect(fromMapUser.isAdmin, isTrue);

      final serialized = adminUser.toMap();
      expect(serialized['role'], 'admin');
    });

    test('Costume serialization and deserialization', () {
      final costume = Costume(
        id: 'c1',
        name: 'Tanjiro Haori',
        anime: 'Demon Slayer',
        storeId: 's1',
        description: 'Bahan katun adem',
        imageUrls: ['https://example.com/tanjiro.jpg'],
        price: 75000,
        sizes: ['M', 'L'],
        isAvailable: true,
      );

      final map = costume.toMap();
      expect(map['name'], 'Tanjiro Haori');
      expect(map['price'], 75000.0);
      expect(map['sizes'], ['M', 'L']);

      final restored = Costume.fromMap(map, 'c1');
      expect(restored.name, costume.name);
      expect(restored.anime, costume.anime);
      expect(restored.sizes, ['M', 'L']);
      expect(restored.isAvailable, isTrue);
    });

    test('Store serialization and deserialization', () {
      final store = Store(
        id: 's1',
        name: 'Wibu Cosplay Hub',
        ownerUid: 'u2',
        city: 'Jakarta Selatan',
        imageUrl: 'https://example.com/logo.jpg',
        rating: 4.9,
      );

      final map = store.toMap();
      expect(map['storeName'], 'Wibu Cosplay Hub');
      expect(map['city'], 'Jakarta Selatan');

      final restored = Store.fromMap(map, 's1');
      expect(restored.name, 'Wibu Cosplay Hub');
      expect(restored.city, 'Jakarta Selatan');
    });

    test('RentalTransaction status handling', () {
      final tx = RentalTransaction(
        id: 'tx1',
        userId: 'u1',
        costumeId: 'c1',
        startDate: DateTime(2026, 10, 1),
        endDate: DateTime(2026, 10, 3),
        totalPrice: 150000,
        status: RentalStatus.pending,
        size: 'L',
      );

      final map = tx.toMap();
      expect(map['status'], 'pending');
      expect(map['size'], 'L');

      final restored = RentalTransaction.fromMap(map, 'tx1');
      expect(restored.status, RentalStatus.pending);
      expect(restored.size, 'L');
    });
  });
}
