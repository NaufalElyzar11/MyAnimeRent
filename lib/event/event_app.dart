import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../config/event_safety.dart';
import '../config/theme.dart';
import 'catalog_controller.dart';
import 'catalog_repository.dart';
import 'contact_service.dart';
import 'event_pages.dart';
import 'event_widgets.dart';
import '../screens/home_screen.dart';
import '../screens/search_screen.dart';
import '../screens/wishlist_screen.dart';
import '../screens/profile_screen.dart';
import 'event_session_pages.dart';

class EventApp extends StatefulWidget {
  const EventApp({
    super.key,
    this.repository,
    this.contactGateway,
    this.initialLocation = '/home',
    this.initialThemeMode = ThemeMode.system,
  });
  final CatalogRepository? repository;
  final ContactGateway? contactGateway;
  final String initialLocation;
  final ThemeMode initialThemeMode;

  @override
  State<EventApp> createState() => _EventAppState();
}

class _EventAppState extends State<EventApp> {
  late final CatalogController _catalog;
  late final GoRouter _router;
  late ThemeMode _themeMode;

  @override
  void initState() {
    super.initState();
    EventSafety.disableCloud();
    _themeMode = widget.initialThemeMode;
    _catalog = CatalogController(widget.repository ?? LocalCatalogRepository())
      ..initialize();
    _router = GoRouter(
      initialLocation: widget.initialLocation,
      redirect: (context, state) {
        final path = state.uri.path;
        if (path == '/') return '/home';
        if (!isEventPublicPath(path)) return '/unavailable';
        return null;
      },
      errorBuilder: (context, state) => const EventUnavailableScreen(),
      routes: [
        StatefulShellRoute.indexedStack(
          builder: (context, state, shell) => EventShell(shell: shell),
          branches: [
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/home',
                  builder: (context, state) => CatalogBody(
                    builder: (context, snapshot) =>
                        HomeScreen(catalogSnapshot: snapshot),
                  ),
                ),
              ],
            ),
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/search',
                  builder: (context, state) =>
                      const SearchScreen(catalogBody: EventSearchScreen()),
                ),
              ],
            ),
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/favorites-local',
                  builder: (context, state) =>
                      const WishlistScreen(catalogBody: EventFavoritesBody()),
                ),
              ],
            ),
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/guest',
                  builder: (context, state) =>
                      const ProfileScreen(guestBody: EventGuestBody()),
                ),
              ],
            ),
          ],
        ),
        GoRoute(
          path: '/detail/:costumeId',
          builder: (context, state) =>
              EventProductScreen(productId: state.pathParameters['costumeId']!),
        ),
        GoRoute(
          path: '/store_detail/:storeId',
          builder: (context, state) =>
              EventStoreScreen(storeId: state.pathParameters['storeId']!),
        ),
        GoRoute(
          path: '/stores',
          builder: (context, state) => const EventStoresScreen(),
        ),
        GoRoute(
          path: '/unavailable',
          builder: (context, state) => const EventUnavailableScreen(),
        ),
        GoRoute(
          path: '/see_more/:anime',
          builder: (context, state) =>
              EventSeriesScreen(series: state.pathParameters['anime']!),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _router.dispose();
    _catalog.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MultiProvider(
    providers: [
      ChangeNotifierProvider.value(value: _catalog),
      Provider<ContactGateway>.value(
        value: widget.contactGateway ?? WhatsAppGateway(),
      ),
      Provider<EventPreferences>.value(
        value: EventPreferences(
          themeMode: _themeMode,
          setTheme: (value) => setState(() => _themeMode = value),
          reset: () {
            FocusManager.instance.primaryFocus?.unfocus();
            _catalog.resetSession();
            _router.go('/home');
          },
        ),
      ),
    ],
    child: MaterialApp.router(
      title: 'MyAnimeRent • Uji Event',
      debugShowCheckedModeBanner: false,
      locale: const Locale('id'),
      supportedLocales: const [Locale('id'), Locale('en')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      theme: eventTheme(AppThemeData.lightTheme()),
      darkTheme: eventTheme(AppThemeData.darkTheme()),
      themeMode: _themeMode,
      routerConfig: _router,
    ),
  );
}

bool isEventPublicPath(String path) =>
    const {
      '/home',
      '/search',
      '/stores',
      '/unavailable',
      '/favorites-local',
      '/guest',
    }.contains(path) ||
    path.startsWith('/see_more/') ||
    RegExp(r'^/(detail|store_detail)/[a-zA-Z0-9_-]+$').hasMatch(path);

ThemeData eventTheme(ThemeData base) {
  final linkColor = base.brightness == Brightness.dark
      ? const Color(0xFFC5A6FF)
      : AppColors.purple;
  final shape = RoundedRectangleBorder(borderRadius: BorderRadius.circular(12));
  return base.copyWith(
    colorScheme: base.colorScheme.copyWith(
      primary: linkColor,
      onPrimary: Colors.white,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.purple,
        foregroundColor: Colors.white,
        minimumSize: const Size(48, 48),
        shape: shape,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.purple,
        foregroundColor: Colors.white,
        minimumSize: const Size(48, 48),
        shape: shape,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(48, 48),
        shape: shape,
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
    ),
    iconButtonTheme: const IconButtonThemeData(
      style: ButtonStyle(minimumSize: WidgetStatePropertyAll(Size(48, 48))),
    ),
  );
}
