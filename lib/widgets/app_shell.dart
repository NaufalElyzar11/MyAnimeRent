import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../providers/store_admin_provider.dart';

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
    if (location == '/store') return 4;
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Tab "Toko" hanya di aplikasi utama dan hanya untuk owner/staf toko (bukan mode event).
    final store = navigationShell == null ? context.watch<StoreAdminProvider>() : null;
    final showStore = store?.hasStores ?? false;
    final openRequests = store?.openCount ?? 0;
    var selected = navigationShell?.currentIndex ?? _getSelectedIndex(context);
    if (selected > (showStore ? 4 : 3)) selected = 0;
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(child: child),
      bottomNavigationBar: NavigationBar(
        selectedIndex: selected,
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
            case 4:
              context.go('/store');
              break;
          }
        },
        destinations: [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Beranda',
          ),
          NavigationDestination(
            icon: Icon(Icons.search_outlined),
            selectedIcon: Icon(Icons.search),
            label: 'Cari',
          ),
          NavigationDestination(
            icon: Icon(Icons.favorite_outline),
            selectedIcon: Icon(Icons.favorite),
            label: navigationShell == null ? 'Wishlist' : 'Favorit',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Profil',
          ),
          if (showStore)
            NavigationDestination(
              icon: Badge(
                isLabelVisible: openRequests > 0,
                label: Text('$openRequests'),
                child: const Icon(Icons.storefront_outlined),
              ),
              selectedIcon: Badge(
                isLabelVisible: openRequests > 0,
                label: Text('$openRequests'),
                child: const Icon(Icons.storefront),
              ),
              label: 'Toko',
            ),
        ],
      ),
    );
  }
}
