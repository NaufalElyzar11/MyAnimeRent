import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../config/theme.dart';
import '../models/store.dart';
import '../providers/costume_provider.dart';
import '../widgets/ui_kit.dart';

/// Direktori toko rental yang sudah tayang.
class StoreScreen extends StatefulWidget {
  const StoreScreen({super.key});

  @override
  State<StoreScreen> createState() => _StoreScreenState();
}

class _StoreScreenState extends State<StoreScreen> {
  String _q = '';

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<CostumeProvider>();
    final q = _q.trim().toLowerCase();
    final stores = provider.stores
        .where((s) => q.isEmpty || s.name.toLowerCase().contains(q) || s.city.toLowerCase().contains(q))
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Toko rental'),
        leading: IconButton(
          tooltip: 'Kembali',
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.canPop() ? context.pop() : context.go('/home'),
        ),
      ),
      body: provider.isLoading && provider.stores.isEmpty
          ? ListView(
              padding: const EdgeInsets.all(AppSpacing.page),
              children: [for (var i = 0; i < 5; i++) const Padding(padding: EdgeInsets.only(bottom: 10), child: SkeletonBox(height: 76))],
            )
          : RefreshIndicator(
              onRefresh: () => context.read<CostumeProvider>().loadData(force: true),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(AppSpacing.page, 4, AppSpacing.page, 24),
                children: [
                  TextField(
                    decoration: const InputDecoration(hintText: 'Cari nama toko atau kota…', prefixIcon: Icon(Icons.search)),
                    onChanged: (v) => setState(() => _q = v),
                  ),
                  const SizedBox(height: 12),
                  if (stores.isEmpty)
                    EmptyState(
                      icon: Icons.storefront_outlined,
                      title: provider.stores.isEmpty ? 'Belum ada toko yang tayang' : 'Toko tidak ditemukan',
                    )
                  else
                    for (final s in stores) Padding(padding: const EdgeInsets.only(bottom: 10), child: _StoreRow(store: s)),
                ],
              ),
            ),
    );
  }
}

class _StoreRow extends StatelessWidget {
  const _StoreRow({required this.store});
  final Store store;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push('/store_detail/${store.id}'),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              StoreAvatar(name: store.name, imageUrl: store.imageUrl, size: 52),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(store.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: theme.textTheme.titleSmall),
                        ),
                        if (store.verifiedAt != null) ...[
                          const SizedBox(width: 4),
                          const Icon(Icons.verified_rounded, size: 16, color: AppColors.purple),
                        ],
                      ],
                    ),
                    Text(
                      [store.city, '${store.productCount} kostum', if (store.shipsIntercity) 'kirim antarkota']
                          .where((x) => x.isNotEmpty)
                          .join(' · '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(color: muted),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: muted),
            ],
          ),
        ),
      ),
    );
  }
}
