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
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    final place = [
      if (costume.storeName.isNotEmpty) costume.storeName,
      if (costume.city.isNotEmpty) costume.city,
    ].join(' · ');

    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
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
                  if (costume.imageUrls.isNotEmpty)
                    CachedNetworkImage(
                      imageUrl: costume.imageUrls.first,
                      fit: BoxFit.cover,
                      fadeInDuration: const Duration(milliseconds: 200),
                      placeholder: (_, _) => Container(color: theme.colorScheme.surfaceContainerHighest),
                      errorWidget: (_, _, _) => _NoPhoto(color: muted),
                    )
                  else
                    _NoPhoto(color: muted),
                  Positioned(
                    top: 6,
                    right: 6,
                    child: Consumer<WishlistProvider>(
                      builder: (context, wishlistProvider, _) {
                        final saved = wishlistProvider.isItemInWishlist(costume.id);
                        return Material(
                          color: Colors.white.withValues(alpha: 0.92),
                          shape: const CircleBorder(),
                          elevation: 1,
                          child: InkWell(
                            customBorder: const CircleBorder(),
                            onTap: () async {
                              final result = await wishlistProvider.toggleWishlist(costume.id);
                              if (result == null && context.mounted) {
                                // Tamu: favorit tersimpan di akun, jadi minta masuk dulu.
                                context.push('/login?from=${Uri.encodeComponent('/detail/${costume.id}')}');
                              }
                            },
                            child: Padding(
                              padding: const EdgeInsets.all(7),
                              child: Icon(
                                saved ? Icons.favorite : Icons.favorite_border,
                                semanticLabel: saved ? 'Hapus dari favorit' : 'Simpan ke favorit',
                                color: saved ? AppColors.pink : Colors.black87,
                                size: 18,
                              ),
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
              padding: const EdgeInsets.fromLTRB(10, 9, 10, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    costume.name,
                    style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600, height: 1.25),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Icon(Icons.place_outlined, size: 13, color: muted),
                      const SizedBox(width: 2),
                      Expanded(
                        child: Text(
                          place.isEmpty ? costume.anime : place,
                          style: theme.textTheme.bodySmall?.copyWith(color: muted),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Flexible(
                        child: Text.rich(
                          costume.hasPrice
                              ? TextSpan(children: [
                                  TextSpan(
                                    text: 'Rp${_price.format(costume.price.toInt())}',
                                    style: TextStyle(fontWeight: FontWeight.w700, color: theme.colorScheme.primary),
                                  ),
                                  TextSpan(
                                    text: ' /${costume.durationDays} hari',
                                    style: TextStyle(color: muted, fontSize: 11),
                                  ),
                                ])
                              : TextSpan(text: 'Tanya harga', style: TextStyle(color: muted)),
                          style: theme.textTheme.bodyMedium,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (costume.sizes.isNotEmpty) ...[
                        const SizedBox(width: 6),
                        Text(
                          costume.sizes.length > 3
                              ? '${costume.sizes.take(3).join('·')}+'
                              : costume.sizes.join('·'),
                          style: theme.textTheme.labelSmall?.copyWith(color: muted),
                        ),
                      ],
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

final _price = NumberFormat.decimalPattern('id_ID');

class _NoPhoto extends StatelessWidget {
  const _NoPhoto({required this.color});
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        child: Icon(Icons.checkroom_outlined, size: 40, color: color),
      );
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
