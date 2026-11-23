import 'dart:io';
import 'dart:ui' as ui;

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myanimerent/event/catalog_repository.dart';
import 'package:myanimerent/event/event_app.dart';

import 'support/event_test_support.dart';

import 'package:myanimerent/screens/home_screen.dart';
import 'package:myanimerent/screens/search_screen.dart';
import 'package:myanimerent/screens/wishlist_screen.dart';
import 'package:myanimerent/screens/profile_screen.dart';
import 'package:myanimerent/widgets/app_shell.dart';
import 'package:myanimerent/widgets/costume_card.dart';

Future<void> openProduct(WidgetTester tester, String id) async {
  final finder = find.byKey(ValueKey('product-$id'));
  await showMainTarget(tester, finder);
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Future<void> showMainTarget(WidgetTester tester, Finder finder) async {
  await tester.scrollUntilVisible(
    finder,
    200,
    scrollable: find
        .descendant(
          of: find.byType(ListView).last,
          matching: find.byType(Scrollable),
        )
        .first,
    maxScrolls: 80,
  );
  await tester.pumpAndSettle();
  await Scrollable.ensureVisible(tester.element(finder), alignment: 0.5);
  await tester.pumpAndSettle();
}

Future<void> chooseFilter(WidgetTester tester, String key, String label) async {
  await tester.ensureVisible(find.byKey(ValueKey(key)));
  await tester.tap(find.byKey(ValueKey(key)));
  await tester.pumpAndSettle();
  await tester.tap(find.text(label).last);
  await tester.pumpAndSettle();
}

Future<void> capture(WidgetTester tester, String name) async {
  if (!const bool.fromEnvironment('EVENT_CAPTURE')) return;
  final boundary = tester.renderObject<RenderRepaintBoundary>(
    find.byKey(const ValueKey('preview-boundary')),
  );
  await tester.runAsync(() async {
    final image = await boundary.toImage();
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    final directory = Directory('build/event-evidence')
      ..createSync(recursive: true);
    File('${directory.path}/$name.png')
        .writeAsBytesSync(data!.buffer.asUint8List());
    image.dispose();
  });
}

void main() {
  setUpAll(() async {
    final fonts = FontLoader('Poppins');
    for (final weight in ['Regular', 'Medium', 'SemiBold', 'Bold']) {
      fonts.addFont(rootBundle.load('assets/fonts/Poppins-$weight.ttf'));
    }
    await fonts.load();
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
  });
  testWidgets('basis lama dipakai: beranda, carousel, dan empat tab', (
    tester,
  ) async {
    await tester.pumpWidget(const EventApp());
    await tester.pumpAndSettle();
    expect(find.byType(HomeScreen), findsOneWidget);
    expect(find.byType(AppShell), findsOneWidget);
    expect(find.byType(PageView), findsOneWidget);
    expect(
      tester.widget<NavigationBar>(find.byType(NavigationBar)).destinations,
      hasLength(4),
    );
    await tester.tap(
      find.descendant(
        of: find.byType(NavigationBar),
        matching: find.text('Cari'),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(SearchScreen), findsOneWidget);
    expect(Firebase.apps, isEmpty);
  });

  testWidgets(
    'favorit dan pengaturan profil berfungsi lokal, reset membersihkannya',
    (tester) async {
      await tester.pumpWidget(const EventApp(initialLocation: '/search'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const ValueKey('catalog-query')), '2B');
      await tester.pumpAndSettle();
      await showMainTarget(
        tester,
        find.byKey(const ValueKey('favorite-demo-2b-a')),
      );
      await tester.tap(find.byKey(const ValueKey('favorite-demo-2b-a')));
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(
          of: find.byType(NavigationBar),
          matching: find.text('Favorit'),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(WishlistScreen), findsOneWidget);
      expect(find.byType(CostumeCard), findsOneWidget);
      expect(find.byKey(const ValueKey('product-demo-2b-a')), findsOneWidget);
      await tester.tap(
        find.descendant(
          of: find.byType(NavigationBar),
          matching: find.text('Profil'),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(ProfileScreen), findsOneWidget);
      expect(find.text('Pengunjung'), findsOneWidget);
      await showMainTarget(
        tester,
        find.byKey(const ValueKey('theme-choice-dark')),
      );
      await tester.tap(find.byKey(const ValueKey('theme-choice-dark')));
      await tester.pumpAndSettle();
      expect(
        Theme.of(tester.element(find.byType(ProfileScreen))).brightness,
        Brightness.dark,
      );
      await showMainTarget(tester, find.byKey(const ValueKey('reset-session')));
      await tester.tap(find.byKey(const ValueKey('reset-session')));
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(
          of: find.byType(NavigationBar),
          matching: find.text('Favorit'),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Favorit masih kosong'), findsOneWidget);
      expect(Firebase.apps, isEmpty);
    },
  );

  testWidgets('kelompok seri dari beranda tetap membuka katalog seri', (
    tester,
  ) async {
    await tester.pumpWidget(
      EventApp(
        initialLocation: '/see_more/${Uri.encodeComponent('NieR:Automata')}',
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('2 kostum'), findsOneWidget);
    expect(find.byType(CostumeCard), findsNWidgets(2));
    expect(Firebase.apps, isEmpty);
  });
  testWidgets('tamu mencari, filter, detail, toko; kembali menjaga konteks', (
    tester,
  ) async {
    await tester.pumpWidget(const EventApp());
    await tester.pumpAndSettle();
    expect(find.text('Temukan kostum pilihanmu'), findsOneWidget);
    expect(Firebase.apps, isEmpty);
    await tester.tap(find.byKey(const ValueKey('home-search')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('catalog-query')), '2B');
    await tester.pumpAndSettle();
    expect(find.text('2 kostum ditemukan'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('open-filters')));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<TextFormField>(find.byKey(const ValueKey('filter-min-price')))
          .enabled,
      isFalse,
    );
    await chooseFilter(tester, 'filter-city', 'Banjarmasin');
    await chooseFilter(tester, 'filter-size', 'M');
    await chooseFilter(tester, 'filter-price-basis', 'Paket 3 hari');
    await tester.enterText(
      find.byKey(const ValueKey('filter-min-price')),
      '100000',
    );
    await tester.enterText(
      find.byKey(const ValueKey('filter-max-price')),
      '125000',
    );
    await tester.ensureVisible(find.byKey(const ValueKey('apply-filters')));
    await tester.tap(find.byKey(const ValueKey('apply-filters')));
    await tester.pumpAndSettle();
    expect(find.text('1 kostum ditemukan'), findsOneWidget);
    await openProduct(tester, 'demo-2b-a');
    expect(find.text('Detail kostum'), findsOneWidget);
    await showMainTarget(tester, find.byKey(const ValueKey('store-profile')));
    await tester.tap(find.byKey(const ValueKey('store-profile')));
    await tester.pumpAndSettle();
    expect(find.text('Profil toko'), findsOneWidget);
    expect(find.text('Toko Ilustrasi A'), findsOneWidget);
    expect(find.text('Banjarmasin'), findsOneWidget);
    await tester.tap(find.byTooltip('Kembali'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Kembali'));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<TextField>(find.byKey(const ValueKey('catalog-query')))
          .controller!
          .text,
      '2B',
    );
    await tester.drag(
      find.byKey(const PageStorageKey('event-search-results')),
      const Offset(0, 1000),
    );
    await tester.pumpAndSettle();
    expect(find.text('1 kostum ditemukan'), findsOneWidget);
    expect(find.text('Basis: paket 3 hari'), findsOneWidget);
    expect(find.text('Ukuran M'), findsOneWidget);
    expect(Firebase.apps, isEmpty);
  });

  testWidgets('posisi daftar dipertahankan setelah kembali dari detail', (
    tester,
  ) async {
    await tester.pumpWidget(const EventApp(initialLocation: '/search'));
    await tester.pumpAndSettle();
    final list = find.byKey(const PageStorageKey('event-search-results'));
    await tester.drag(list, const Offset(0, -900));
    await tester.pumpAndSettle();
    await showMainTarget(
      tester,
      find.byKey(const ValueKey('product-demo-yor-c')),
    );
    final controller = tester.widget<ListView>(list).controller!;
    final offset = controller.offset;
    expect(offset, greaterThan(0));
    await tester.tap(find.byKey(const ValueKey('product-demo-yor-c')));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Kembali'));
    await tester.pumpAndSettle();
    expect(controller.offset, closeTo(offset, 0.1));
  });

  testWidgets('hasil nol dan kegagalan lokal mempunyai tampilan berbeda', (
    tester,
  ) async {
    await tester.pumpWidget(const EventApp(initialLocation: '/search'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('catalog-query')),
      'tak-ada-kostum-ini',
    );
    await tester.pumpAndSettle();
    expect(find.text('0 kostum ditemukan'), findsOneWidget);
    expect(find.text('Tidak ada kostum yang cocok'), findsOneWidget);
    for (final failure in CatalogFailure.values) {
      await tester.pumpWidget(
        EventApp(key: ValueKey(failure), repository: FailedRepository(failure)),
      );
      await tester.pumpAndSettle();
      expect(
        find.text(
          failure == CatalogFailure.invalidData
              ? 'Data katalog tidak valid'
              : 'Katalog gagal dibaca',
        ),
        findsOneWidget,
      );
      expect(find.text('Tidak ada kostum yang cocok'), findsNothing);
    }
  });

  testWidgets(
    'route langsung privat/admin/rental tidak menjalankan aplikasi lama',
    (tester) async {
      for (final path in [
        '/admin',
        '/admin/costume/add',
        '/admin/store/edit/test',
        '/profile',
        '/wishlist',
        '/rental_history',
        '/login',
        '/signup',
        '/settings',
        '/booking/test',
        '/rentals/test',
      ]) {
        await tester.pumpWidget(
          EventApp(key: ValueKey(path), initialLocation: path),
        );
        await tester.pumpAndSettle();
        expect(
          find.text('Halaman tidak tersedia pada versi uji'),
          findsOneWidget,
          reason: path,
        );
        expect(Firebase.apps, isEmpty, reason: path);
        expect(tester.takeException(), isNull, reason: path);
      }
    },
  );

  testWidgets('kontak fixture nonaktif; preview tidak membuka WhatsApp', (
    tester,
  ) async {
    final gateway = RecordingContactGateway();
    await tester.pumpWidget(
      EventApp(initialLocation: '/detail/demo-2b-a', contactGateway: gateway),
    );
    await tester.pumpAndSettle();
    await showMainTarget(tester, find.byKey(const ValueKey('contact-preview')));
    await tester.tap(find.byKey(const ValueKey('contact-preview')));
    await tester.pumpAndSettle();
    expect(find.text('Ringkasan pertanyaan'), findsOneWidget);
    expect(gateway.opened, isEmpty);
    expect(
      tester
          .widget<FilledButton>(find.byKey(const ValueKey('open-whatsapp')))
          .onPressed,
      isNull,
    );
    expect(
      find.textContaining('Kontak nonaktif: ini data ilustratif'),
      findsOneWidget,
    );
  });

  testWidgets(
    'kontak berizin hanya dibuka oleh aksi eksplisit; kegagalan bisa disalin',
    (tester) async {
      final snapshot = await authorizedTestSnapshot();
      final gateway = RecordingContactGateway();
      await tester.pumpWidget(
        EventApp(
          repository: SnapshotRepository(snapshot),
          contactGateway: gateway,
          initialLocation: '/detail/demo-2b-a',
        ),
      );
      await tester.pumpAndSettle();
      await showMainTarget(tester, find.text('M'));
      await tester.tap(find.text('M').last);
      await showMainTarget(
        tester,
        find.byKey(const ValueKey('contact-preview')),
      );
      await tester.tap(find.byKey(const ValueKey('contact-preview')));
      await tester.pumpAndSettle();
      expect(gateway.opened, isEmpty);
      await tester.ensureVisible(find.byKey(const ValueKey('open-whatsapp')));
      await tester.tap(find.byKey(const ValueKey('open-whatsapp')));
      await tester.pumpAndSettle();
      expect(gateway.opened, hasLength(1));
      expect(
        gateway.opened.single.queryParameters['text'],
        contains('Ukuran: M'),
      );
      expect(find.byKey(const ValueKey('contact-failure')), findsOneWidget);
      expect(find.text('Salin ringkasan'), findsOneWidget);
      expect(find.text('Salin kontak bisnis'), findsOneWidget);
      expect(Firebase.apps, isEmpty);
    },
  );

  testWidgets('reset sesi membersihkan query dan filter lokal', (tester) async {
    await tester.pumpWidget(const EventApp(initialLocation: '/search'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('catalog-query')), '2B');
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Tema dan sesi uji'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Reset sesi uji'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('home-search')));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<TextField>(find.byKey(const ValueKey('catalog-query')))
          .controller!
          .text,
      isEmpty,
    );
    expect(find.text('9 kostum ditemukan'), findsOneWidget);
  });

  for (final mode in [ThemeMode.light, ThemeMode.dark]) {
    testWidgets(
      '320px font besar: beranda, cari, filter, detail dan toko ${mode.name}',
      (tester) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = const Size(320, 800);
        tester.platformDispatcher.textScaleFactorTestValue = 2;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        for (final path in [
          '/home',
          '/search',
          '/detail/demo-2b-a',
          '/store_detail/demo-store-a',
        ]) {
          await tester.pumpWidget(
            RepaintBoundary(
              key: const ValueKey('preview-boundary'),
              child: EventApp(
                key: ValueKey('$path-$mode'),
                initialLocation: path,
                initialThemeMode: mode,
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull, reason: path);
          if (path == '/search') {
            await tester.enterText(
              find.byKey(const ValueKey('catalog-query')),
              '2B',
            );
            await tester.pumpAndSettle();
            await capture(tester, 'search-${mode.name}-320-font200');
            await tester.tap(find.byKey(const ValueKey('open-filters')));
            await tester.pumpAndSettle();
            await chooseFilter(tester, 'filter-city', 'Kabupaten Banjar');
            expect(tester.takeException(), isNull);
            await tester.ensureVisible(find.text('Batal'));
            await tester.tap(find.text('Batal'));
            await tester.pumpAndSettle();
          }
          if (path == '/detail/demo-2b-a') {
            await showMainTarget(
              tester,
              find.byKey(const ValueKey('contact-preview')),
            );
            await tester.tap(find.byKey(const ValueKey('contact-preview')));
            await tester.pumpAndSettle();
            expect(tester.takeException(), isNull);
            await tester.ensureVisible(find.text('Tutup'));
            await tester.tap(find.text('Tutup'));
            await tester.pumpAndSettle();
          }
        }
      },
    );
  }

  testWidgets('390px: tampilan utama dan keyboard tetap dapat digunakan', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetViewInsets);
    for (final page in {
      'home': '/home',
      'search': '/search',
      'detail': '/detail/demo-2b-a',
      'store': '/store_detail/demo-store-a',
    }.entries) {
      await tester.pumpWidget(
        RepaintBoundary(
          key: const ValueKey('preview-boundary'),
          child: EventApp(
            key: ValueKey(page.key),
            initialLocation: page.value,
            initialThemeMode: ThemeMode.light,
          ),
        ),
      );
      await tester.pumpAndSettle();
      if (page.key == 'search') {
        await tester.enterText(
          find.byKey(const ValueKey('catalog-query')),
          '2B',
        );
        await tester.pumpAndSettle();
        tester.view.viewInsets = const FakeViewPadding(bottom: 300);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        tester.view.resetViewInsets();
        await tester.pumpAndSettle();
      }
      expect(tester.takeException(), isNull, reason: page.key);
      await capture(tester, '${page.key}-light-390');
    }
  });
}
