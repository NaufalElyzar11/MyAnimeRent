import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../config/theme.dart';
import '../providers/costume_provider.dart';
import '../models/costume.dart';
import '../widgets/costume_card.dart';
import '../widgets/store_card.dart';
import '../event/catalog.dart';
import '../event/catalog_controller.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, this.catalogSnapshot});
  final CatalogSnapshot? catalogSnapshot;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentBannerPage = 0;

  @override
  void initState() {
    super.initState();
    if (widget.catalogSnapshot != null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<CostumeProvider>().loadData();
    });
  }

  @override
  Widget build(BuildContext context) {
    if (widget.catalogSnapshot != null) {
      return _publicCatalog(context, widget.catalogSnapshot!);
    }
    final provider = context.watch<CostumeProvider>();
    final theme = Theme.of(context);

    // Only show full-screen spinner if we have no costumes yet
    if (provider.isLoading && provider.costumes.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (provider.error != null && provider.costumes.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(provider.error!),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: () =>
                  context.read<CostumeProvider>().loadData(force: true),
              child: const Text('Try Again'),
            ),
          ],
        ),
      );
    }

    final costumesByAnime = provider.costumesByAnime;
    final allImages = provider.costumes.expand((c) => c.imageUrls).toList();
    final bannerImages = allImages.take(4).toList();

    return RefreshIndicator(
      onRefresh: () => context.read<CostumeProvider>().loadData(force: true),
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Brand Header with Logo
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Image.asset(
                    'assets/images/logo.png',
                    height: 44,
                    fit: BoxFit.contain,
                  ),
                  Container(
                    decoration: BoxDecoration(
                      color: AppColors.pink.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.search, color: AppColors.purple),
                      onPressed: () => context.go('/search'),
                      tooltip: 'Search Costumes',
                    ),
                  ),
                ],
              ),
            ),

            // Image Slider / Banner 1:1 Square (kept 1:1 with dot indicator)
            if (bannerImages.isNotEmpty) ...[
              AspectRatio(
                aspectRatio: 1.0,
                child: PageView.builder(
                  itemCount: bannerImages.length,
                  onPageChanged: (i) => setState(() => _currentBannerPage = i),
                  itemBuilder: (context, index) {
                    return Padding(
                      padding: const EdgeInsets.all(4),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: CachedNetworkImage(
                          imageUrl: bannerImages[index],
                          fit: BoxFit.cover,
                          width: double.infinity,
                          height: double.infinity,
                          placeholder: (_, _) => Container(
                            color: theme.colorScheme.surfaceContainerHighest,
                            child: const Center(
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          ),
                          errorWidget: (_, _, _) => Container(
                            color: theme.colorScheme.surfaceContainerHighest,
                            child: const Icon(Icons.broken_image, size: 48),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(bannerImages.length, (i) {
                  final isSelected = _currentBannerPage == i;
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    width: isSelected ? 18 : 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: isSelected
                          ? theme.colorScheme.primary
                          : theme.colorScheme.onSurface.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  );
                }),
              ),
            ],

            const SizedBox(height: 24),

            // Top Cosrent (Stores)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Top Cosrent', style: theme.textTheme.titleLarge),
                GestureDetector(
                  onTap: () => context.push('/stores'),
                  child: Text(
                    'See More',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 140,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: provider.stores.take(3).length,
                itemBuilder: (context, index) {
                  final store = provider.stores[index];
                  return GestureDetector(
                    onTap: () => context.push('/store_detail/${store.id}'),
                    child: Card(
                      margin: const EdgeInsets.only(right: 8),
                      elevation: 3,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Container(
                        width: 120,
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: CachedNetworkImage(
                                imageUrl: store.imageUrl,
                                width: 72,
                                height: 72,
                                fit: BoxFit.cover,
                                errorWidget: (_, _, _) =>
                                    const Icon(Icons.store, size: 40),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              store.name.isNotEmpty ? store.name : store.city,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),

            const SizedBox(height: 24),

            // Costumes grouped by anime
            for (final entry
                in (costumesByAnime.entries.toList()
                  ..sort((a, b) => a.key.compareTo(b.key))))
              _CostumeSection(
                title: entry.value.first.anime,
                costumes: entry.value,
                onSeeMore: () => context.push(
                  '/see_more/${Uri.encodeComponent(entry.value.first.anime)}',
                ),
                onCostumeClick: (id) => context.push('/detail/$id'),
              ),
          ],
        ),
      ),
    );
  }

  /// Same brand header, square carousel, store strip and series sections as the
  /// existing home. Only its public data source and required metadata differ.
  Widget _publicCatalog(BuildContext context, CatalogSnapshot snapshot) {
    final catalog = context.watch<CatalogController>();
    final theme = Theme.of(context);
    final bySeries = <String, List<CatalogProduct>>{};
    for (final p in snapshot.products) {
      bySeries.putIfAbsent(p.series, () => []).add(p);
    }
    final featured = snapshot.products.take(4).toList();
    return RefreshIndicator(
      onRefresh: catalog.initialize,
      child: ListView(
        key: PageStorageKey('event-home-${catalog.session}'),
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Image.asset(
                  'assets/images/logo.png',
                  height: 44,
                  semanticLabel: 'MyAnimeRent',
                ),
              ),
              Container(
                decoration: BoxDecoration(
                  color: AppColors.pink.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: IconButton(
                  tooltip: 'Cari kostum',
                  icon: const Icon(Icons.search, color: AppColors.purple),
                  onPressed: () => context.go('/search'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text('Temukan kostum pilihanmu', style: theme.textTheme.titleLarge),
          const SizedBox(height: 12),
          TextField(
            key: const ValueKey('home-search'),
            readOnly: true,
            onTap: () => context.go('/search'),
            decoration: const InputDecoration(
              labelText: 'Cari kostum',
              hintText: 'Karakter, seri, atau nama kostum',
              prefixIcon: Icon(Icons.search),
            ),
          ),
          const SizedBox(height: 12),
          const Text('Katalog lokal • Tetap dapat dicari tanpa internet'),
          const SizedBox(height: 16),
          if (featured.isNotEmpty) ...[
            AspectRatio(
              aspectRatio: 1,
              child: PageView.builder(
                itemCount: featured.length,
                onPageChanged: (i) => setState(() => _currentBannerPage = i),
                itemBuilder: (context, index) => Padding(
                  padding: const EdgeInsets.all(4),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: GestureDetector(
                      onTap: () =>
                          context.push('/detail/${featured[index].id}'),
                      child: Image.asset(
                        featured[index].imageAssets.first,
                        fit: BoxFit.cover,
                        semanticLabel:
                            '${snapshot.illustrative ? 'Ilustrasi' : 'Foto'} ${featured[index].name}',
                        errorBuilder: (_, _, _) => const Center(
                          child: Icon(Icons.broken_image_outlined),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var i = 0; i < featured.length; i++)
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    width: i == _currentBannerPage ? 18 : 6,
                    height: 6,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(3),
                      color: i == _currentBannerPage
                          ? theme.colorScheme.primary
                          : theme.colorScheme.onSurface.withValues(alpha: 0.2),
                    ),
                  ),
              ],
            ),
          ],
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: Text('Toko rental', style: theme.textTheme.titleLarge),
              ),
              TextButton(
                onPressed: () => context.push('/stores'),
                child: const Text('Lihat semua'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final store in snapshot.stores.take(3))
                  SizedBox(
                    width: 150,
                    child: Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: StoreCard.catalog(
                        store: store,
                        city: snapshot.cityName(store.cityCode),
                        onTap: () => context.push('/store_detail/${store.id}'),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          for (final series in bySeries.keys.toList()..sort())
            _CostumeSection(
              title: series,
              costumes: const [],
              onCostumeClick: (_) {},
              onSeeMore: () =>
                  context.push('/see_more/${Uri.encodeComponent(series)}'),
              catalogCards: [
                for (final p in bySeries[series]!)
                  CostumeCard.catalog(
                    product: p,
                    snapshot: snapshot,
                    onTap: () => context.push('/detail/${p.id}'),
                  ),
              ],
            ),
          if (snapshot.products.isEmpty)
            const Text('Belum ada kostum di katalog ini.'),
        ],
      ),
    );
  }
}

class _CostumeSection extends StatelessWidget {
  final String title;
  final List<Costume> costumes;
  final VoidCallback onSeeMore;
  final void Function(String) onCostumeClick;
  final List<Widget>? catalogCards;

  const _CostumeSection({
    required this.title,
    required this.costumes,
    required this.onSeeMore,
    required this.onCostumeClick,
    this.catalogCards,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(child: Text(title, style: theme.textTheme.titleLarge)),
            GestureDetector(
              onTap: onSeeMore,
              child: Text(
                catalogCards == null ? 'See More' : 'Lihat semua',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.primary,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (catalogCards != null)
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final card in catalogCards!)
                  SizedBox(
                    width: 185,
                    child: Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: card,
                    ),
                  ),
              ],
            ),
          )
        else
          SizedBox(
            height: 240,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: costumes.length,
              itemBuilder: (context, index) {
                return SizedBox(
                  width: 160,
                  child: Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: CostumeCard(
                      costume: costumes[index],
                      onTap: () => onCostumeClick(costumes[index].id),
                    ),
                  ),
                );
              },
            ),
          ),
        const SizedBox(height: 24),
      ],
    );
  }
}
