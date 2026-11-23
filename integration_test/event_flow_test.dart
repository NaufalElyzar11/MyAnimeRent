import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:myanimerent/config/event_safety.dart';
import 'package:myanimerent/event/event_app.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'Android: katalog lokal tanpa akun sampai toko dan preview kontak',
    (tester) async {
      await tester.pumpWidget(const EventApp());
      await tester.pumpAndSettle();
      expect(EventSafety.cloudDisabled, isTrue);
      expect(appFlavor, 'event');
      expect(
        tester.widget<NavigationBar>(find.byType(NavigationBar)).destinations,
        hasLength(4),
      );
      expect(Firebase.apps, isEmpty);
      await tester.tap(find.byKey(const ValueKey('home-search')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const ValueKey('catalog-query')), '2B');
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pumpAndSettle();
      expect(find.text('2 kostum ditemukan'), findsOneWidget);
      await scrollTo(tester, find.byKey(const ValueKey('favorite-demo-2b-a')));
      await tester.tap(find.byKey(const ValueKey('favorite-demo-2b-a')));
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(
          of: find.byType(NavigationBar),
          matching: find.text('Favorit'),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('product-demo-2b-a')), findsOneWidget);
      await tester.tap(
        find.descendant(
          of: find.byType(NavigationBar),
          matching: find.text('Cari'),
        ),
      );
      await tester.pumpAndSettle();
      await scrollTo(tester, find.byKey(const ValueKey('product-demo-2b-a')));
      await tester.tap(find.byKey(const ValueKey('product-demo-2b-a')));
      await tester.pumpAndSettle();
      await scrollTo(tester, find.byKey(const ValueKey('store-profile')));
      await tester.tap(find.byKey(const ValueKey('store-profile')));
      await tester.pumpAndSettle();
      expect(find.text('Profil toko'), findsOneWidget);
      await tester.tap(find.byTooltip('Kembali'));
      await tester.pumpAndSettle();
      await scrollTo(tester, find.byKey(const ValueKey('contact-preview')));
      await tester.tap(find.byKey(const ValueKey('contact-preview')));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<FilledButton>(find.byKey(const ValueKey('open-whatsapp')))
            .onPressed,
        isNull,
      );
      expect(Firebase.apps, isEmpty);
    },
  );
}

Future<void> scrollTo(WidgetTester tester, Finder target) async {
  await tester.scrollUntilVisible(
    target,
    200,
    maxScrolls: 80,
    scrollable: find
        .descendant(
          of: find.byType(ListView).last,
          matching: find.byType(Scrollable),
        )
        .first,
  );
  await tester.pumpAndSettle();
  await Scrollable.ensureVisible(tester.element(target), alignment: 0.5);
  await tester.pumpAndSettle();
}
