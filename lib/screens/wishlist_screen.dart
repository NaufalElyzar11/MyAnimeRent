import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../providers/wishlist_provider.dart';
import '../widgets/costume_card.dart';

class WishlistScreen extends StatefulWidget {
  const WishlistScreen({super.key});

  @override
  State<WishlistScreen> createState() => _WishlistScreenState();
}

class _WishlistScreenState extends State<WishlistScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<WishlistProvider>().loadWishlist();
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<WishlistProvider>();

    return Scaffold(
      appBar: AppBar(title: const Text('My Wishlist')),
      body: provider.isLoading
          ? const Center(child: CircularProgressIndicator())
          : provider.wishlistItems.isEmpty
              ? const Center(child: Text('Your wishlist is empty.'))
              : GridView.builder(
                  padding: const EdgeInsets.all(16),
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 200,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                    childAspectRatio: 0.65,
                  ),
                  itemCount: provider.wishlistItems.length,
                  itemBuilder: (context, index) {
                    final costume = provider.wishlistItems[index];
                    return CostumeCard(
                      costume: costume,
                      onTap: () => context.push('/detail/${costume.id}'),
                    );
                  },
                ),
    );
  }
}
