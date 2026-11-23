import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myanimerent/config/event_safety.dart';
import 'package:myanimerent/models/rental_transaction.dart';
import 'package:myanimerent/providers/rental_provider.dart';
import 'package:myanimerent/providers/auth_provider.dart';
import 'package:myanimerent/services/auth_service.dart';
import 'package:myanimerent/services/database_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'service lama dan objek yang sudah dibuat menolak Firebase pada mode event',
    () async {
      final database = DatabaseService();
      final auth = AuthService();
      EventSafety.disableCloud();
      expect(DatabaseService.new, throwsStateError);
      expect(AuthService.new, throwsStateError);
      expect(AuthProvider.new, throwsStateError);
      expect(RentalProvider.new, throwsStateError);
      await expectLater(
        database.createRental(
          RentalTransaction(
            id: 'test',
            userId: 'test',
            costumeId: 'test',
            startDate: DateTime(2026, 11, 20),
            endDate: DateTime(2026, 11, 22),
            totalPrice: 1,
            status: RentalStatus.pending,
            size: 'M',
          ),
        ),
        throwsStateError,
      );
      await expectLater(
        database.updateRentalStatus('test', RentalStatus.cancelled),
        throwsStateError,
      );
      await expectLater(
        database.updateCostume('test', {'bookedDates': []}),
        throwsStateError,
      );
      await expectLater(
        database.updateStore('test', {'membership': 'paid'}),
        throwsStateError,
      );
      await expectLater(
        database.updateReview('test', {'rating': 5}),
        throwsStateError,
      );
      await expectLater(
        auth.signUp('unused@example.invalid', 'unused', 'Uji'),
        throwsStateError,
      );
      await expectLater(auth.updateUserProfile(name: 'Uji'), throwsStateError);
      await expectLater(
        auth.signIn('unused@example.invalid', 'unused'),
        throwsStateError,
      );
      expect(Firebase.apps, isEmpty);
    },
  );
}
