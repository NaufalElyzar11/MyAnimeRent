import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../providers/wishlist_provider.dart';
import '../config/theme.dart';
import '../widgets/ui_kit.dart';

class WishlistScreen extends StatefulWidget {
  const WishlistScreen({super.key, this.catalogBody});
  final Widget? catalogBody;

  @override
  State<WishlistScreen> createState() => _WishlistScreenState();
}

class _WishlistScreenState extends State<WishlistScreen> {
  @override
  void initState() {
    super.initState();
    if (widget.catalogBody != null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<WishlistProvider>().loadWishlist();
    });
  }

  @override
  Widget build(BuildContext context) {
    if (widget.catalogBody != null) {
      return Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: const Text('Favorit'),
          automaticallyImplyLeading: false,
        ),
        body: widget.catalogBody,
      );
    }
    final provider = context.watch<WishlistProvider>();

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: Text(provider.wishlistItems.isEmpty ? 'Favorit' : 'Favorit (${provider.wishlistItems.length})'),
        backgroundColor: Colors.transparent,
        automaticallyImplyLeading: false,
      ),
      body: RefreshIndicator(
        onRefresh: () => context.read<WishlistProvider>().loadWishlist(),
        child: provider.isLoading && provider.wishlistItems.isEmpty
            ? ListView(children: const [
                Padding(padding: EdgeInsets.all(AppSpacing.page), child: CostumeGridSkeleton()),
              ])
            : provider.wishlistItems.isEmpty
                ? LayoutBuilder(
                    builder: (context, constraints) => SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      child: ConstrainedBox(
                        constraints: BoxConstraints(minHeight: constraints.maxHeight),
                        child: Center(
                          child: EmptyState(
                            icon: Icons.favorite_border_rounded,
                            title: 'Belum ada favorit',
                            message: 'Ketuk ikon hati di kostum yang kamu suka agar mudah ditemukan lagi.',
                            actionLabel: 'Jelajahi kostum',
                            onAction: () => context.go('/home'),
                          ),
                        ),
                      ),
                    ),
                  )
                : CostumeGridView(
                    costumes: provider.wishlistItems,
                    physics: const AlwaysScrollableScrollPhysics(),
                    onTap: (c) => context.push('/detail/${c.id}'),
                  ),
      ),
    );
  }
}
