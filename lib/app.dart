import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'providers/auth_provider.dart';
import 'providers/costume_provider.dart';
import 'providers/rental_provider.dart';
import 'providers/review_provider.dart';
import 'providers/wishlist_provider.dart';
import 'providers/settings_provider.dart';
import 'config/routes.dart';
import 'config/theme.dart';

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
  late final ReviewProvider _reviewProvider;
  late final WishlistProvider _wishlistProvider;
  late final GoRouter _router;

  @override
  void initState() {
    super.initState();
    _authProvider = AuthProvider();
    _settingsProvider = SettingsProvider()..loadSettings();
    _costumeProvider = CostumeProvider();
    _rentalProvider = RentalProvider();
    _reviewProvider = ReviewProvider();
    _wishlistProvider = WishlistProvider();
    _router = createRouter(_authProvider);
  }

  @override
  void dispose() {
    _authProvider.dispose();
    _settingsProvider.dispose();
    _costumeProvider.dispose();
    _rentalProvider.dispose();
    _reviewProvider.dispose();
    _wishlistProvider.dispose();
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
        ChangeNotifierProvider.value(value: _reviewProvider),
        ChangeNotifierProvider.value(value: _wishlistProvider),
        ChangeNotifierProvider.value(value: _settingsProvider),
      ],
      child: ListenableBuilder(
        listenable: _settingsProvider,
        builder: (context, _) {
          return MaterialApp.router(
            title: 'MyAnimeRent',
            debugShowCheckedModeBanner: false,
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
