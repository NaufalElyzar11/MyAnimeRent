import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../models/store_admin.dart';
import '../../models/store_catalog.dart';
import '../../services/store_catalog_service.dart';
import '../../services/supabase_service.dart';
import '../product_detail_screen.dart' show rupiah;

enum _CatalogFilter { all, draft, published, archived }

/// Tab katalog toko: semua listing (termasuk draft) dan apa yang kurang agar bisa terbit.
class StoreCatalogTab extends StatefulWidget {
  const StoreCatalogTab({super.key, required this.store});
  final MyStore store;

  @override
  State<StoreCatalogTab> createState() => _StoreCatalogTabState();
}

class _StoreCatalogTabState extends State<StoreCatalogTab> with AutomaticKeepAliveClientMixin {
  final _service = StoreCatalogService();
  List<StoreProductSummary> _items = [];
  _CatalogFilter _filter = _CatalogFilter.all;
  bool _loading = true;
  String? _error;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final items = await _service.listProducts(widget.store.id);
      if (!mounted) return;
      setState(() {
        _items = items;
        _error = null;
        _loading = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _loading = false;
      });
    }
  }

  bool _matches(StoreProductSummary p) => _inFilter(_filter, p);

  static bool _inFilter(_CatalogFilter f, StoreProductSummary p) => switch (f) {
        _CatalogFilter.all => !p.isArchived,
        _CatalogFilter.draft => p.isDraft,
        _CatalogFilter.published => p.isPublished,
        _CatalogFilter.archived => p.isArchived,
      };

  String _label(_CatalogFilter f) => switch (f) {
        _CatalogFilter.all => 'Aktif',
        _CatalogFilter.draft => 'Draft',
        _CatalogFilter.published => 'Terbit',
        _CatalogFilter.archived => 'Arsip',
      };

  Future<void> _open(String path) async {
    await context.push(path);
    if (mounted) _load();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final theme = Theme.of(context);
    final items = _items.where(_matches).toList();

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'tambah-kostum',
        onPressed: () => _open('/store/products/new?store=${widget.store.id}'),
        icon: const Icon(Icons.add),
        label: const Text('Tambah kostum'),
      ),
      body: Column(
        children: [
          SizedBox(
            height: 52,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              children: [
                for (final f in _CatalogFilter.values)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text('${_label(f)} (${_items.where((p) => _inFilter(f, p)).length})'),
                      selected: _filter == f,
                      onSelected: (_) => setState(() => _filter = f),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _load,
              child: _loading && _items.isEmpty
                  ? ListView(children: const [SizedBox(height: 120), Center(child: CircularProgressIndicator())])
                  : items.isEmpty
                      ? ListView(
                          padding: const EdgeInsets.all(32),
                          children: [
                            const SizedBox(height: 40),
                            Icon(Icons.checkroom_outlined, size: 56, color: theme.colorScheme.primary),
                            const SizedBox(height: 12),
                            Text(
                              _error ??
                                  (_filter == _CatalogFilter.all
                                      ? 'Belum ada kostum. Tekan "Tambah kostum" untuk membuat listing pertama.'
                                      : 'Tidak ada listing di sini.'),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.fromLTRB(12, 0, 12, 96),
                          itemCount: items.length,
                          separatorBuilder: (_, _) => const SizedBox(height: 8),
                          itemBuilder: (_, i) => _ProductTile(
                            product: items[i],
                            onTap: () => _open('/store/products/${items[i].id}'),
                          ),
                        ),
            ),
          ),
        ],
      ),
    );
  }
}

class ProductStatusChip extends StatelessWidget {
  const ProductStatusChip({super.key, required this.status});
  final String status;

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      'published' => Colors.green.shade700,
      'draft' => Colors.orange.shade800,
      _ => Colors.grey.shade700,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(8)),
      child: Text(productStatusLabels[status] ?? status,
          style: TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 12)),
    );
  }
}

class _ProductTile extends StatelessWidget {
  const _ProductTile({required this.product, required this.onTap});
  final StoreProductSummary product;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final p = product;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: SizedBox(
                  width: 64,
                  height: 64,
                  child: p.coverUrl.isEmpty
                      ? Container(
                          color: theme.colorScheme.surfaceContainerHighest,
                          child: const Icon(Icons.add_a_photo_outlined),
                        )
                      : CachedNetworkImage(imageUrl: p.coverUrl, fit: BoxFit.cover),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(p.title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
                        ),
                        const SizedBox(width: 6),
                        ProductStatusChip(status: p.status),
                      ],
                    ),
                    if (p.characterName != null || p.franchiseName != null)
                      Text([?p.characterName, ?p.franchiseName].join(' · '), style: theme.textTheme.bodySmall),
                    Text(
                      [
                        if (p.priceIdr != null) '${rupiah(p.priceIdr!)} / ${p.durationDays ?? 1} hari',
                        if (p.sizes.isNotEmpty) 'Ukuran ${p.sizes.join(', ')}',
                        '${p.imageCount}/3 foto',
                      ].join(' · '),
                      style: theme.textTheme.bodySmall,
                    ),
                    if (!p.isArchived && p.missing.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          'Belum bisa terbit: ${missingText(p.missing)}',
                          style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.error),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
