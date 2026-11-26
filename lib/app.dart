import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'config/routes.dart';
import 'config/theme.dart';
import 'providers/auth_provider.dart';
import 'providers/costume_provider.dart';
import 'providers/notification_provider.dart';
import 'providers/rental_provider.dart';
import 'providers/settings_provider.dart';
import 'providers/wishlist_provider.dart';
import 'services/push_service.dart';

class MyAnimeRentApp extends StatefulWidget {
  const MyAnimeRentApp({super.key});

  @override
  State<MyAnimeRentApp> createState() => _MyAnimeRentAppState();
}

class _MyAnimeRentAppState extends State<MyAnimeRentApp> {
  late final AuthProvider _authProvider;
  late final SettingsProvider _settingsProvider;
  late final CostumeProvider _costumeProvider;
  late final RentalProvider _rentalProvider;
  late final WishlistProvider _wishlistProvider;
  late final NotificationProvider _notificationProvider;
  late final GoRouter _router;
  String? _sessionUserId;

  @override
  void initState() {
    super.initState();
    _authProvider = AuthProvider();
    _settingsProvider = SettingsProvider()..loadSettings();
    _costumeProvider = CostumeProvider();
    _rentalProvider = RentalProvider();
    _wishlistProvider = WishlistProvider();
    _notificationProvider = NotificationProvider()
      ..onNew = (n) {
        if (n.requestId != null) _rentalProvider.loadRequests();
      };
    _router = createRouter(_authProvider);
    _authProvider.addListener(_onAuthChanged);
    _onAuthChanged();
    PushService.listenTaps((requestId) => _router.push('/requests/$requestId'));
  }

  /// Data pribadi dimuat saat login dan dibersihkan saat logout / ganti akun.
  void _onAuthChanged() {
    final userId = _authProvider.isLoggedIn ? _authProvider.userId : null;
    if (userId == _sessionUserId) return;
    _sessionUserId = userId;
    if (userId == null) {
      _wishlistProvider.clear();
      _rentalProvider.clear();
      _notificationProvider.stop();
      return;
    }
    _wishlistProvider.loadWishlist();
    _rentalProvider.loadRequests();
    _notificationProvider.start(userId);
    PushService.register();
  }

  @override
  void dispose() {
    _authProvider.removeListener(_onAuthChanged);
    _authProvider.dispose();
    _settingsProvider.dispose();
    _costumeProvider.dispose();
    _rentalProvider.dispose();
    _wishlistProvider.dispose();
    _notificationProvider.dispose();
    _router.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: _authProvider),
        ChangeNotifierProvider.value(value: _costumeProvider),
        ChangeNotifierProvider.value(value: _rentalProvider),
        ChangeNotifierProvider.value(value: _wishlistProvider),
        ChangeNotifierProvider.value(value: _notificationProvider),
        ChangeNotifierProvider.value(value: _settingsProvider),
      ],
      child: ListenableBuilder(
        listenable: _settingsProvider,
        builder: (context, _) {
          return MaterialApp.router(
            title: 'MyAnimeRent',
            debugShowCheckedModeBanner: false,
            locale: const Locale('id'),
            supportedLocales: const [Locale('id'), Locale('en')],
            localizationsDelegates: GlobalMaterialLocalizations.delegates,
            theme: AppThemeData.lightTheme(),
            darkTheme: AppThemeData.darkTheme(),
            themeMode: _settingsProvider.themeMode,
            routerConfig: _router,
          );
        },
      ),
    );
  }
}
