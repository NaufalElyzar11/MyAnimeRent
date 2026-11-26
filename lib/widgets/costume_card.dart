import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';

import '../models/costume.dart';
import '../providers/wishlist_provider.dart';
import '../config/theme.dart';
import '../event/catalog.dart';
import '../event/catalog_controller.dart';
import '../event/contact_service.dart';

class CostumeCard extends StatelessWidget {
  final Costume? costume;
  final VoidCallback onTap;
  final CatalogProduct? catalogProduct;
  final CatalogSnapshot? catalogSnapshot;

  const CostumeCard({super.key, required this.costume, required this.onTap})
    : catalogProduct = null,
      catalogSnapshot = null;

  const CostumeCard.catalog({
    super.key,
    required CatalogProduct product,
    required CatalogSnapshot snapshot,
    required this.onTap,
  }) : catalogProduct = product,
       catalogSnapshot = snapshot,
       costume = null;

  @override
  Widget build(BuildContext context) {
    if (catalogProduct != null) {
      return _PublicCostumeCard(
        product: catalogProduct!,
        snapshot: catalogSnapshot!,
        onTap: onTap,
      );
    }
    final costume = this.costume!;
    final formatter = NumberFormat('#,###', 'id_ID');
    final theme = Theme.of(context);

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AspectRatio(
              aspectRatio: 1,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  costume.imageUrls.isNotEmpty
                      ? CachedNetworkImage(
                          imageUrl: costume.imageUrls.first,
                          fit: BoxFit.cover,
                          placeholder: (_, _) => Container(
                            color: theme.colorScheme.surfaceContainerHighest,
                            child: const Center(
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          ),
                          errorWidget: (_, _, _) => Container(
                            color: theme.colorScheme.surfaceContainerHighest,
                            child: const Icon(
                              Icons.image_not_supported,
                              size: 40,
                            ),
                          ),
                        )
                      : Container(
                          color: theme.colorScheme.surfaceContainerHighest,
                          child: const Icon(
                            Icons.image_not_supported,
                            size: 40,
                          ),
                        ),
                  // Rating Badge (Top Left)
                  if (costume.rating > 0)
                    Positioned(
                      top: 8,
                      left: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.55),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.star,
                              color: AppColors.yellow,
                              size: 12,
                            ),
                            const SizedBox(width: 3),
                            Text(
                              costume.rating.toStringAsFixed(1),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  // Wishlist Toggle Button (Top Right)
                  Positioned(
                    top: 6,
                    right: 6,
                    child: Consumer<WishlistProvider>(
                      builder: (context, wishlistProvider, _) {
                        final isWishlisted = wishlistProvider.isItemInWishlist(
                          costume.id,
                        );
                        return GestureDetector(
                          onTap: () async {
                            final result = await wishlistProvider.toggleWishlist(costume.id);
                            if (result == null && context.mounted) {
                              // Tamu: wishlist tersimpan di akun, jadi minta masuk dulu.
                              context.push('/login?from=${Uri.encodeComponent('/detail/${costume.id}')}');
                            }
                          },
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.45),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              isWishlisted
                                  ? Icons.favorite
                                  : Icons.favorite_border,
                              color: isWishlisted ? Colors.red : Colors.white,
                              size: 16,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    costume.name,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    costume.storeName.isNotEmpty
                        ? '${costume.storeName}${costume.city.isEmpty ? '' : ' · ${costume.city}'}'
                        : costume.anime,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    costume.hasPrice
                        ? 'Rp ${formatter.format(costume.price.toInt())} / ${costume.durationDays} hari'
                        : 'Harga belum diinformasikan',
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.primary,
                    ),
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

/// The existing square-photo card, extended with public store/price metadata.
/// Local favorites belong only to this event session, never to an account.
class _PublicCostumeCard extends StatelessWidget {
  const _PublicCostumeCard({
    required this.product,
    required this.snapshot,
    required this.onTap,
  });
  final CatalogProduct product;
  final CatalogSnapshot snapshot;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final catalog = context.watch<CatalogController>();
    final store = snapshot.store(product.storeId);
    final favorite = catalog.isFavorite(product.id);
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        key: ValueKey('product-${product.id}'),
        onTap: onTap,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AspectRatio(
              aspectRatio: 1,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Image.asset(
                    product.imageAssets.first,
                    fit: BoxFit.cover,
                    semanticLabel:
                        '${snapshot.illustrative ? 'Ilustrasi' : 'Foto'} ${product.name}',
                    errorBuilder: (_, _, _) =>
                        const Center(child: Icon(Icons.broken_image_outlined)),
                  ),
                  Positioned(
                    top: 4,
                    right: 4,
                    child: Material(
                      color: Colors.black.withValues(alpha: 0.62),
                      shape: const CircleBorder(),
                      child: IconButton(
                        key: ValueKey('favorite-${product.id}'),
                        tooltip: favorite
                            ? 'Hapus dari favorit lokal'
                            : 'Simpan favorit lokal',
                        color: favorite ? AppColors.pink : Colors.white,
                        icon: Icon(
                          favorite ? Icons.favorite : Icons.favorite_border,
                        ),
                        onPressed: () => catalog.toggleFavorite(product.id),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.name,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(product.series, style: theme.textTheme.bodySmall),
                  const SizedBox(height: 6),
                  Text(
                    '${store.name} · ${snapshot.cityName(store.cityCode)}',
                    style: theme.textTheme.bodySmall,
                  ),
                  Text(
                    'Ukuran: ${product.sizes.isEmpty ? 'belum diinformasikan' : product.sizes.join(', ')}',
                    style: theme.textTheme.bodySmall,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    priceLabel(product.price),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
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
