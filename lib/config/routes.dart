import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../providers/auth_provider.dart';
import '../screens/login_screen.dart';
import '../screens/signup_screen.dart';
import '../screens/home_screen.dart';
import '../screens/search_screen.dart';
import '../screens/product_detail_screen.dart';
import '../screens/wishlist_screen.dart';
import '../screens/rental_history_screen.dart';
import '../screens/profile_screen.dart';
import '../screens/settings_screen.dart';
import '../screens/store_screen.dart';
import '../screens/store_detail_screen.dart';
import '../screens/see_more_screen.dart';
import '../widgets/app_shell.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>();
final _shellNavigatorKey = GlobalKey<NavigatorState>();

GoRouter createRouter(AuthProvider authProvider) {
  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    refreshListenable: authProvider,
    initialLocation: '/login',
    redirect: (context, state) {
      final loggedIn = authProvider.isLoggedIn;
      final loggingIn = state.matchedLocation == '/login' ||
          state.matchedLocation == '/signup';

      if (!loggedIn && !loggingIn) return '/login';
      if (loggedIn && loggingIn) return '/home';
      return null;
    },
    routes: [
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/signup',
        builder: (context, state) => const SignupScreen(),
      ),
      ShellRoute(
        navigatorKey: _shellNavigatorKey,
        builder: (context, state, child) => AppShell(child: child),
        routes: [
          GoRoute(
            path: '/home',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: HomeScreen(),
            ),
          ),
          GoRoute(
            path: '/search',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: SearchScreen(),
            ),
          ),
          GoRoute(
            path: '/wishlist',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: WishlistScreen(),
            ),
          ),
          GoRoute(
            path: '/profile',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: ProfileScreen(),
            ),
          ),
        ],
      ),
      GoRoute(
        path: '/detail/:costumeId',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) {
          final costumeId = state.pathParameters['costumeId']!;
          return ProductDetailScreen(costumeId: costumeId);
        },
      ),
      GoRoute(
        path: '/settings',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const SettingsScreen(),
      ),
      GoRoute(
        path: '/rental_history',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const RentalHistoryScreen(),
      ),
      GoRoute(
        path: '/stores',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const StoreScreen(),
      ),
      GoRoute(
        path: '/store_detail/:storeId',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) {
          final storeId = state.pathParameters['storeId']!;
          return StoreDetailScreen(storeId: storeId);
        },
      ),
      GoRoute(
        path: '/see_more/:anime',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) {
          final anime = state.pathParameters['anime']!;
          return SeeMoreScreen(anime: anime);
        },
      ),
    ],
  );
}
