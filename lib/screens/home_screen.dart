import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../config/theme.dart';
import '../providers/costume_provider.dart';
import '../models/costume.dart';
import '../widgets/costume_card.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<CostumeProvider>().loadData();
    });
  }

  @override
  Widget build(BuildContext context) {
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
              onPressed: () => context.read<CostumeProvider>().loadData(force: true),
              child: const Text('Try Again'),
            ),
          ],
        ),
      );
    }

    final costumesByAnime = provider.costumesByAnime;
    final allImages = provider.costumes.expand((c) => c.imageUrls).toList();
    final bannerImages = allImages.take(4).toList();

    return SingleChildScrollView(
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

          // Image Slider / Banner 1:1 Square (matching Kotlin aspectRatio(1f))
          if (bannerImages.isNotEmpty)
            AspectRatio(
              aspectRatio: 1.0,
              child: PageView.builder(
                itemCount: bannerImages.length,
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

          const SizedBox(height: 24),

          // Top Cosrent (Stores)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Top Cosrent', style: theme.textTheme.titleLarge),
              GestureDetector(
                onTap: () => context.push('/stores'),
                child: Text('See More',
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(color: theme.colorScheme.primary)),
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
                  onTap: () => context.push('/stores'),
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
          for (final entry in (costumesByAnime.entries.toList()
            ..sort((a, b) => a.key.compareTo(b.key))))
            _CostumeSection(
              title: entry.value.first.anime,
              costumes: entry.value,
              onSeeMore: () =>
                  context.push('/see_more/${Uri.encodeComponent(entry.value.first.anime)}'),
              onCostumeClick: (id) => context.push('/detail/$id'),
            ),
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

  const _CostumeSection({
    required this.title,
    required this.costumes,
    required this.onSeeMore,
    required this.onCostumeClick,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(title, style: theme.textTheme.titleLarge),
            GestureDetector(
              onTap: onSeeMore,
              child: Text('See More',
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(color: theme.colorScheme.primary)),
            ),
          ],
        ),
        const SizedBox(height: 8),
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
