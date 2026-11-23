import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class AppShell extends StatelessWidget {
  final Widget child;
  const AppShell({super.key, required this.child, this.navigationShell});

  /// Optional public/local navigation; the main app retains its original routes.
  final StatefulNavigationShell? navigationShell;

  static int _getSelectedIndex(BuildContext context) {
    final location = GoRouterState.of(context).matchedLocation;
    if (location.startsWith('/home')) return 0;
    if (location.startsWith('/search')) return 1;
    if (location.startsWith('/wishlist')) return 2;
    if (location.startsWith('/profile')) return 3;
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(child: child),
      bottomNavigationBar: NavigationBar(
        selectedIndex:
            navigationShell?.currentIndex ?? _getSelectedIndex(context),
        onDestinationSelected: (index) {
          if (navigationShell != null) {
            FocusScope.of(context).unfocus();
            navigationShell!.goBranch(index);
            return;
          }
          switch (index) {
            case 0:
              context.go('/home');
              break;
            case 1:
              context.go('/search');
              break;
            case 2:
              context.go('/wishlist');
              break;
            case 3:
              context.go('/profile');
              break;
          }
        },
        destinations: [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: navigationShell == null ? 'Home' : 'Beranda',
          ),
          NavigationDestination(
            icon: Icon(Icons.search_outlined),
            selectedIcon: Icon(Icons.search),
            label: navigationShell == null ? 'Search' : 'Cari',
          ),
          NavigationDestination(
            icon: Icon(Icons.favorite_outline),
            selectedIcon: Icon(Icons.favorite),
            label: navigationShell == null ? 'Wishlist' : 'Favorit',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: navigationShell == null ? 'Profile' : 'Profil',
          ),
        ],
      ),
    );
  }
}
