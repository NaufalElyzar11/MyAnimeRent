import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../providers/auth_provider.dart';
import '../screens/home_screen.dart';
import '../screens/login_screen.dart';
import '../screens/notifications_screen.dart';
import '../screens/product_detail_screen.dart';
import '../screens/profile_screen.dart';
import '../screens/rental_history_screen.dart';
import '../screens/request_detail_screen.dart';
import '../screens/search_screen.dart';
import '../screens/see_more_screen.dart';
import '../screens/settings_screen.dart';
import '../screens/signup_screen.dart';
import '../screens/store/product_editor_screen.dart';
import '../screens/store/store_home_screen.dart';
import '../screens/store/store_profile_screen.dart';
import '../screens/store/store_request_detail_screen.dart';
import '../screens/store/unit_schedule_screen.dart';
import '../screens/store_detail_screen.dart';
import '../screens/store_screen.dart';
import '../screens/wishlist_screen.dart';
import '../widgets/app_shell.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>();
final _shellNavigatorKey = GlobalKey<NavigatorState>();

/// Halaman yang butuh akun. Katalog, detail, toko dan profil (versi tamu) bisa dibuka tanpa login.
bool isPrivatePath(String path) =>
    path == '/wishlist' ||
    path == '/rental_history' ||
    path == '/notifications' ||
    path.startsWith('/requests') ||
    path == '/store' ||
    path.startsWith('/store/');

GoRouter createRouter(AuthProvider authProvider) {
  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    refreshListenable: authProvider,
    initialLocation: '/home',
    redirect: (context, state) {
      final loggedIn = authProvider.isLoggedIn;
      final path = state.matchedLocation;
      final onAuthPage = path == '/login' || path == '/signup';
      if (!loggedIn && isPrivatePath(path)) {
        return Uri(path: '/login', queryParameters: {'from': state.uri.toString()}).toString();
      }
      if (loggedIn && onAuthPage) {
        final from = state.uri.queryParameters['from'];
        return (from != null && from.startsWith('/') && !from.startsWith('//')) ? from : '/home';
      }
      if (path == '/rental_history') return '/requests';
      return null;
    },
    routes: [
      GoRoute(path: '/', redirect: (_, _) => '/home'),
      GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
      GoRoute(path: '/signup', builder: (context, state) => const SignupScreen()),
      ShellRoute(
        navigatorKey: _shellNavigatorKey,
        builder: (context, state, child) => AppShell(child: child),
        routes: [
          GoRoute(
            path: '/home',
            pageBuilder: (context, state) => const NoTransitionPage(child: HomeScreen()),
          ),
          GoRoute(
            path: '/search',
            pageBuilder: (context, state) => const NoTransitionPage(child: SearchScreen()),
          ),
          GoRoute(
            path: '/wishlist',
            pageBuilder: (context, state) => const NoTransitionPage(child: WishlistScreen()),
          ),
          GoRoute(
            path: '/profile',
            pageBuilder: (context, state) => const NoTransitionPage(child: ProfileScreen()),
          ),
          GoRoute(
            path: '/store',
            pageBuilder: (context, state) => const NoTransitionPage(child: StoreHomeScreen()),
          ),
        ],
      ),
      GoRoute(
        path: '/store/products/new',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => ProductEditorScreen(storeId: state.uri.queryParameters['store']),
      ),
      GoRoute(
        path: '/store/products/:productId',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => ProductEditorScreen(productId: state.pathParameters['productId']),
      ),
      GoRoute(
        path: '/store/profile',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => StoreProfileScreen(storeId: state.uri.queryParameters['store'] ?? ''),
      ),
      GoRoute(
        path: '/store/requests/:requestId',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => StoreRequestDetailScreen(requestId: state.pathParameters['requestId']!),
      ),
      GoRoute(
        path: '/store/units/:unitId',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) {
          final month = state.uri.queryParameters['month'];
          return UnitScheduleScreen(
            storeId: state.uri.queryParameters['store'] ?? '',
            unitId: state.pathParameters['unitId']!,
            initialMonth: month == null ? null : DateTime.tryParse('$month-01'),
          );
        },
      ),
      GoRoute(
        path: '/detail/:costumeId',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => ProductDetailScreen(costumeId: state.pathParameters['costumeId']!),
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
        path: '/requests',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const RentalHistoryScreen(),
        routes: [
          GoRoute(
            path: ':requestId',
            parentNavigatorKey: _rootNavigatorKey,
            builder: (context, state) => RequestDetailScreen(requestId: state.pathParameters['requestId']!),
          ),
        ],
      ),
      GoRoute(
        path: '/notifications',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const NotificationsScreen(),
      ),
      GoRoute(
        path: '/stores',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const StoreScreen(),
      ),
      GoRoute(
        path: '/store_detail/:storeId',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => StoreDetailScreen(storeId: state.pathParameters['storeId']!),
      ),
      GoRoute(
        path: '/see_more/:anime',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => SeeMoreScreen(anime: state.pathParameters['anime']!),
      ),
    ],
  );
}
