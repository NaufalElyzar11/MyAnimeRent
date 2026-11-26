import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../models/costume.dart';
import '../models/store.dart';
import '../providers/costume_provider.dart';
import '../config/theme.dart';
import '../widgets/ui_kit.dart';

/// Profil toko publik + katalognya. [storeId] = slug toko.
class StoreDetailScreen extends StatefulWidget {
  final String storeId;
  const StoreDetailScreen({super.key, required this.storeId});

  @override
  State<StoreDetailScreen> createState() => _StoreDetailScreenState();
}

class _StoreDetailScreenState extends State<StoreDetailScreen> {
  Store? _store;
  List<Costume> _costumes = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final provider = context.read<CostumeProvider>();
    try {
      final results = await Future.wait([
        provider.getStoreById(widget.storeId),
        provider.loadStoreCostumes(widget.storeId),
      ]);
      if (!mounted) return;
      setState(() {
        _store = results[0] as Store?;
        _costumes = results[1] as List<Costume>;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final store = _store;
    final muted = theme.colorScheme.onSurfaceVariant;
    return Scaffold(
      appBar: AppBar(
        title: Text(store?.name ?? 'Profil toko'),
        leading: IconButton(
          tooltip: 'Kembali',
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.canPop() ? context.pop() : context.go('/home'),
        ),
      ),
      body: _loading
          ? ListView(
              padding: const EdgeInsets.all(AppSpacing.page),
              children: const [
                SkeletonBox(height: 120, radius: 20),
                SizedBox(height: 20),
                CostumeGridSkeleton(),
              ],
            )
          : store == null
              ? Center(
                  child: EmptyState(
                    icon: _error != null ? Icons.wifi_off_rounded : Icons.storefront_outlined,
                    title: _error != null ? 'Toko belum bisa dimuat' : 'Toko tidak ditemukan',
                    message: _error != null ? 'Periksa koneksi lalu coba lagi.' : 'Toko ini belum tayang atau sudah tutup.',
                    actionLabel: _error != null ? 'Coba lagi' : null,
                    onAction: _error != null ? _load : null,
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: CustomScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    slivers: [
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(AppSpacing.page, 8, AppSpacing.page, 0),
                        sliver: SliverToBoxAdapter(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  gradient: AppColors.softGradient,
                                  borderRadius: BorderRadius.circular(AppSpacing.radius),
                                ),
                                child: Row(
                                  children: [
                                    StoreAvatar(name: store.name, imageUrl: store.imageUrl, size: 60),
                                    const SizedBox(width: 14),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(store.name,
                                              style: theme.textTheme.titleLarge?.copyWith(color: AppColors.darkGrey)),
                                          const SizedBox(height: 2),
                                          Text(
                                            [store.city, '${_costumes.length} kostum'].where((x) => x.isNotEmpty).join(' · '),
                                            style: theme.textTheme.bodySmall?.copyWith(color: AppColors.darkGrey),
                                          ),
                                          if (store.shipsIntercity || store.verifiedAt != null) ...[
                                            const SizedBox(height: 6),
                                            Wrap(
                                              spacing: 6,
                                              runSpacing: 4,
                                              children: [
                                                if (store.verifiedAt != null)
                                                  const _Badge(icon: Icons.verified_rounded, text: 'Terverifikasi'),
                                                if (store.shipsIntercity)
                                                  const _Badge(icon: Icons.local_shipping_outlined, text: 'Kirim antarkota'),
                                              ],
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (store.description != null && store.description!.isNotEmpty) ...[
                                const SizedBox(height: 16),
                                Text(store.description!, style: theme.textTheme.bodyMedium?.copyWith(height: 1.5)),
                              ],
                              if ((store.policies ?? '').isNotEmpty || (store.shippingNotes ?? '').isNotEmpty) ...[
                                const SizedBox(height: 12),
                                Card(
                                  margin: EdgeInsets.zero,
                                  child: Theme(
                                    data: theme.copyWith(dividerColor: Colors.transparent),
                                    child: ExpansionTile(
                                      leading: const Icon(Icons.rule_rounded),
                                      title: const Text('Aturan sewa & pengiriman'),
                                      childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                                      expandedCrossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        if ((store.policies ?? '').isNotEmpty)
                                          Text(store.policies!, style: theme.textTheme.bodyMedium?.copyWith(height: 1.5)),
                                        if ((store.shippingNotes ?? '').isNotEmpty) ...[
                                          const SizedBox(height: 8),
                                          Text('Pengiriman: ${store.shippingNotes!}',
                                              style: theme.textTheme.bodySmall?.copyWith(color: muted)),
                                        ],
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                              const SizedBox(height: AppSpacing.section),
                              SectionHeader(title: 'Kostum', subtitle: '${_costumes.length} tersedia di toko ini'),
                            ],
                          ),
                        ),
                      ),
                      if (_costumes.isEmpty)
                        const SliverToBoxAdapter(
                          child: EmptyState(icon: Icons.checkroom_outlined, title: 'Belum ada kostum yang tayang'),
                        )
                      else
                        SliverToBoxAdapter(
                          child: CostumeGridView(
                            costumes: _costumes,
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            padding: const EdgeInsets.fromLTRB(AppSpacing.page, 0, AppSpacing.page, 24),
                            onTap: (c) => context.push('/detail/${c.id}'),
                          ),
                        ),
                    ],
                  ),
                ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.85), borderRadius: BorderRadius.circular(20)),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: AppColors.purple),
            const SizedBox(width: 4),
            Text(text,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(color: AppColors.darkGrey, fontWeight: FontWeight.w600)),
          ],
        ),
      );
}
