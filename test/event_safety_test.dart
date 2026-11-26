import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myanimerent/config/event_safety.dart';
import 'package:myanimerent/providers/auth_provider.dart';
import 'package:myanimerent/providers/notification_provider.dart';
import 'package:myanimerent/providers/rental_provider.dart';
import 'package:myanimerent/providers/wishlist_provider.dart';
import 'package:myanimerent/services/auth_service.dart';
import 'package:myanimerent/services/database_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'service cloud (Supabase) dan objek yang sudah dibuat menolak berjalan pada mode event',
    () async {
      final database = DatabaseService();
      final auth = AuthService();
      EventSafety.disableCloud();
      expect(DatabaseService.new, throwsStateError);
      expect(AuthService.new, throwsStateError);
      expect(AuthProvider.new, throwsStateError);
      expect(RentalProvider.new, throwsStateError);
      expect(WishlistProvider.new, throwsStateError);
      expect(NotificationProvider.new, throwsStateError);
      await expectLater(database.searchProducts(query: '2B'), throwsStateError);
      await expectLater(database.getCostumeById('test'), throwsStateError);
      await expectLater(
        database.createRequest(
          idempotencyKey: 'uji-event-0001',
          productId: 'test',
          rentStart: DateTime(2026, 11, 20),
          rentEndExclusive: DateTime(2026, 11, 23),
          contactConsent: false,
        ),
        throwsStateError,
      );
      await expectLater(database.addToWishlist('test', 'test'), throwsStateError);
      await expectLater(database.postMessage('test', 'halo', operationId: 'test'), throwsStateError);
      await expectLater(auth.signUp('unused@example.invalid', 'unused-password', 'Uji'), throwsStateError);
      await expectLater(auth.updateUserProfile(name: 'Uji'), throwsStateError);
      await expectLater(auth.signIn('unused@example.invalid', 'unused'), throwsStateError);
      expect(Firebase.apps, isEmpty);
    },
  );
}
