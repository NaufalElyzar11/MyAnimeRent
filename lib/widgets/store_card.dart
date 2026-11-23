import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../config/theme.dart';
import '../models/store.dart';
import '../event/catalog.dart';

class StoreCard extends StatelessWidget {
  final Store? store;
  final VoidCallback onTap;
  final CatalogStore? catalogStore;
  final String? catalogCity;

  const StoreCard({super.key, required this.store, required this.onTap})
    : catalogStore = null,
      catalogCity = null;

  const StoreCard.catalog({
    super.key,
    required CatalogStore store,
    required String city,
    required this.onTap,
  }) : catalogStore = store,
       catalogCity = city,
       store = null;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (catalogStore != null) {
      return Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  height: 72,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppColors.pink.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.storefront,
                    size: 40,
                    color: theme.colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  catalogStore!.name,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleSmall,
                ),
                Text(
                  catalogCity!,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ),
      );
    }
    final store = this.store!;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: 120,
              width: double.infinity,
              child: CachedNetworkImage(
                imageUrl: store.imageUrl,
                fit: BoxFit.cover,
                placeholder: (_, _) => Container(
                  color: theme.colorScheme.surfaceContainerHighest,
                  child: const Center(
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
                errorWidget: (_, _, _) => Container(
                  color: theme.colorScheme.surfaceContainerHighest,
                  child: const Icon(Icons.store, size: 40),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    store.name,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    store.city,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.star, color: AppColors.yellow, size: 16),
                      const SizedBox(width: 4),
                      Text(
                        store.rating.toStringAsFixed(1),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
