import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../providers/costume_provider.dart';
import '../widgets/costume_card.dart';

class StoreDetailScreen extends StatelessWidget {
  final String storeId;
  const StoreDetailScreen({super.key, required this.storeId});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<CostumeProvider>();
    final theme = Theme.of(context);

    if (provider.isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final store = provider.stores.where((s) => s.id == storeId).firstOrNull;
    if (store == null) {
      return const Scaffold(body: Center(child: Text('Store not found.')));
    }

    final costumes = provider.getCostumesForStore(storeId);

    return Scaffold(
      appBar: AppBar(
        title: Text(store.name),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: Column(
        children: [
          // Store header
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: CachedNetworkImage(
                    imageUrl: store.imageUrl,
                    width: 120,
                    height: 120,
                    fit: BoxFit.cover,
                    errorWidget: (_, __, ___) =>
                        const Icon(Icons.store, size: 60),
                  ),
                ),
                const SizedBox(height: 12),
                Text(store.name,
                    style: theme.textTheme.titleLarge
                        ?.copyWith(fontWeight: FontWeight.bold)),
                Text(store.city,
                    style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant)),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.star, color: Color(0xFFFFC107), size: 18),
                    const SizedBox(width: 4),
                    Text(store.rating.toStringAsFixed(1),
                        style: theme.textTheme.bodyMedium
                            ?.copyWith(color: theme.colorScheme.primary)),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text('Costumes',
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.bold)),
            ),
          ),
          const SizedBox(height: 8),

          // Costumes Grid
          Expanded(
            child: costumes.isEmpty
                ? const Center(child: Text('No costumes found.'))
                : GridView.builder(
                    padding: const EdgeInsets.all(16),
                    gridDelegate:
                        const SliverGridDelegateWithMaxCrossAxisExtent(
                      maxCrossAxisExtent: 200,
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 16,
                      childAspectRatio: 0.6,
                    ),
                    itemCount: costumes.length,
                    itemBuilder: (context, index) {
                      return CostumeCard(
                        costume: costumes[index],
                        onTap: () =>
                            context.push('/detail/${costumes[index].id}'),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
