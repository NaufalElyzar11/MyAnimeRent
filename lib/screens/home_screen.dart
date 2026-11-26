import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../config/supabase_config.dart';
import '../config/theme.dart';
import '../providers/auth_provider.dart';
import '../providers/costume_provider.dart';
import '../providers/notification_provider.dart';
import '../providers/rental_provider.dart';
import '../models/rental_request.dart';
import '../models/store.dart';
import '../widgets/ui_kit.dart';
import 'rental_history_screen.dart' show StatusChip;
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
    return const _MainHome();
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
                'Lihat semua',
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

/// Lonceng notifikasi (atau tombol Masuk untuk tamu).
class _InboxButton extends StatelessWidget {
  const _InboxButton();

  @override
  Widget build(BuildContext context) {
    final loggedIn = context.watch<AuthProvider>().isLoggedIn;
    if (!loggedIn) {
      return OutlinedButton(onPressed: () => context.push('/login'), child: const Text('Masuk'));
    }
    final unread = context.watch<NotificationProvider>().unreadCount;
    return IconButton.filledTonal(
      tooltip: 'Notifikasi',
      onPressed: () => context.push('/notifications'),
      icon: Badge(
        isLabelVisible: unread > 0,
        label: Text(unread > 9 ? '9+' : '$unread'),
        child: const Icon(Icons.notifications_none_rounded),
      ),
    );
  }
}

// ─── Beranda aplikasi utama (Supabase) ─────────────────────────────────────

class _MainHome extends StatelessWidget {
  const _MainHome();

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<CostumeProvider>();
    final theme = Theme.of(context);
    final loading = provider.isLoading && provider.costumes.isEmpty;

    if (provider.error != null && provider.costumes.isEmpty && !provider.isLoading) {
      return Center(
        child: SingleChildScrollView(
          child: Column(
            children: [
              EmptyState(
                icon: Icons.wifi_off_rounded,
                title: 'Katalog belum bisa dimuat',
                message: 'Periksa koneksi internet lalu coba lagi.',
                actionLabel: 'Coba lagi',
                onAction: () => context.read<CostumeProvider>().loadData(force: true),
              ),
              if (kDebugMode)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Text(
                    'Server: ${SupabaseConfig.url}\n'
                    'HP fisik tidak bisa memakai 10.0.2.2 (khusus emulator). '
                    'Lihat README bagian Konfigurasi.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodySmall,
                  ),
                ),
            ],
          ),
        ),
      );
    }

    final series = provider.costumesByAnime.entries.toList()
      ..sort((a, b) {
        final byCount = b.value.length.compareTo(a.value.length);
        return byCount != 0 ? byCount : a.key.compareTo(b.key);
      });

    return RefreshIndicator(
      onRefresh: () => context.read<CostumeProvider>().loadData(force: true),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(0, 8, 0, 24),
        children: [
          const _HomeHeader(),
          Padding(
            padding: const EdgeInsets.fromLTRB(AppSpacing.page, 4, AppSpacing.page, 0),
            child: SearchBarButton(onTap: () => context.go('/search')),
          ),
          if (series.isNotEmpty)
            SizedBox(
              height: 52,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.fromLTRB(AppSpacing.page, 10, AppSpacing.page, 0),
                children: [
                  for (final e in series.take(10))
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ActionChip(
                        label: Text(e.value.first.anime),
                        onPressed: () => context.push('/see_more/${Uri.encodeComponent(e.value.first.anime)}'),
                      ),
                    ),
                ],
              ),
            ),
          const SizedBox(height: 16),
          const _ActiveRequestCard(),
          const _HowItWorks(),
          if (loading)
            const Padding(
              padding: EdgeInsets.all(AppSpacing.page),
              child: CostumeGridSkeleton(),
            )
          else ...[
            if (provider.stores.isNotEmpty) ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.page),
                child: SectionHeader(
                  title: 'Toko rental',
                  subtitle: 'Cosrent yang sudah terdaftar',
                  actionLabel: 'Lihat semua',
                  onAction: () => context.push('/stores'),
                ),
              ),
              _StoreStrip(stores: provider.stores.take(8).toList()),
              const SizedBox(height: AppSpacing.section - 8),
            ],
            if (provider.costumes.isEmpty)
              const EmptyState(
                icon: Icons.checkroom_outlined,
                title: 'Belum ada kostum yang tayang',
                message: 'Tarik layar ke bawah untuk memuat ulang.',
              ),
            for (final e in series)
              _CostumeRow(
                title: e.value.first.anime,
                costumes: e.value,
                onSeeMore: () => context.push('/see_more/${Uri.encodeComponent(e.value.first.anime)}'),
              ),
          ],
        ],
      ),
    );
  }
}

class _HomeHeader extends StatelessWidget {
  const _HomeHeader();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final auth = context.watch<AuthProvider>();
    final name = auth.user?.name.trim().split(RegExp(r'\s+')).first;
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.page, 0, 8, 8),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Image.asset('assets/images/logo.png', height: 30, fit: BoxFit.contain, alignment: Alignment.centerLeft),
                const SizedBox(height: 10),
                Text(
                  name == null || name.isEmpty ? 'Mau cosplay jadi siapa?' : 'Hai, $name!',
                  style: theme.textTheme.titleLarge,
                ),
                Text(
                  'Cek tanggal kosong, ajukan sewa, beres di satu app.',
                  style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
          const _InboxButton(),
        ],
      ),
    );
  }
}

/// Permintaan yang sedang berjalan, agar penyewa tidak perlu mencari statusnya.
class _ActiveRequestCard extends StatelessWidget {
  const _ActiveRequestCard();

  @override
  Widget build(BuildContext context) {
    if (!context.watch<AuthProvider>().isLoggedIn) return const SizedBox.shrink();
    final requests = context.watch<RentalProvider>().requests;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final active = requests
        .where((r) => r.status.isOpen || (r.status == RequestStatus.accepted && r.rentEndExclusive.isAfter(today)))
        .toList();
    if (active.isEmpty) return const SizedBox.shrink();
    final r = active.first;
    final theme = Theme.of(context);
    final fmt = DateFormat('d MMM', 'id_ID');
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.page, 0, AppSpacing.page, AppSpacing.section - 8),
      child: Card(
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => context.push(active.length == 1 ? '/requests/${r.id}' : '/requests'),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: SizedBox(
                    width: 52,
                    height: 52,
                    child: r.coverUrl.isEmpty
                        ? Container(color: theme.colorScheme.surfaceContainerHighest, child: const Icon(Icons.checkroom))
                        : CachedNetworkImage(imageUrl: r.coverUrl, fit: BoxFit.cover),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        active.length == 1 ? 'Permintaan aktif' : '${active.length} permintaan aktif',
                        style: theme.textTheme.labelMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                      ),
                      Text(r.productTitle,
                          maxLines: 1, overflow: TextOverflow.ellipsis, style: theme.textTheme.titleSmall),
                      Text('${fmt.format(r.rentStart)} – ${fmt.format(r.rentEnd)} · ${r.storeName}',
                          maxLines: 1, overflow: TextOverflow.ellipsis, style: theme.textTheme.bodySmall),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                StatusChip(status: r.status),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Penjelasan singkat alur sewa untuk pengguna yang belum pernah mengajukan.
class _HowItWorks extends StatelessWidget {
  const _HowItWorks();

  @override
  Widget build(BuildContext context) {
    final loggedIn = context.watch<AuthProvider>().isLoggedIn;
    if (loggedIn && context.watch<RentalProvider>().requests.isNotEmpty) return const SizedBox.shrink();
    final theme = Theme.of(context);
    Widget step(IconData icon, String title, String text) => Expanded(
          child: Column(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: Colors.white.withValues(alpha: 0.85),
                child: Icon(icon, size: 20, color: AppColors.pinkDeep),
              ),
              const SizedBox(height: 6),
              Text(title,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.labelLarge?.copyWith(color: AppColors.darkGrey, fontWeight: FontWeight.w700)),
              Text(text,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.labelSmall?.copyWith(color: AppColors.darkGrey.withValues(alpha: 0.75))),
            ],
          ),
        );
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.page, 0, AppSpacing.page, AppSpacing.section - 8),
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 14, 12, 14),
        decoration: BoxDecoration(gradient: AppColors.softGradient, borderRadius: BorderRadius.circular(AppSpacing.radius)),
        child: Column(
          children: [
            Text('Sewa tanpa chat bolak-balik',
                style: theme.textTheme.titleSmall?.copyWith(color: AppColors.darkGrey, fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                step(Icons.event_available_outlined, 'Cek tanggal', 'Lihat yang sudah dipesan'),
                step(Icons.send_outlined, 'Ajukan', 'Pilih ukuran & tanggal'),
                step(Icons.verified_outlined, 'Dikonfirmasi', 'Toko mengunci jadwalmu'),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StoreStrip extends StatelessWidget {
  const _StoreStrip({required this.stores});
  final List<Store> stores;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scale = MediaQuery.textScalerOf(context).scale(14).clamp(14.0, 22.0) / 14;
    return SizedBox(
      height: 72 * scale + 8,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.page),
        itemCount: stores.length,
        separatorBuilder: (_, _) => const SizedBox(width: 10),
        itemBuilder: (context, i) {
          final store = stores[i];
          return SizedBox(
            width: 220,
            child: Card(
              margin: const EdgeInsets.only(bottom: 4),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: () => context.push('/store_detail/${store.id}'),
                child: Padding(
                  padding: const EdgeInsets.all(10),
                  child: Row(
                    children: [
                      StoreAvatar(name: store.name, imageUrl: store.imageUrl, size: 46),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(store.name,
                                maxLines: 1, overflow: TextOverflow.ellipsis, style: theme.textTheme.titleSmall),
                            Text(
                              [
                                store.city,
                                if (store.productCount > 0) '${store.productCount} kostum',
                              ].where((x) => x.isNotEmpty).join(' · '),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Satu baris kostum per seri (geser ke samping).
class _CostumeRow extends StatelessWidget {
  const _CostumeRow({required this.title, required this.costumes, required this.onSeeMore});
  final String title;
  final List<Costume> costumes;
  final VoidCallback onSeeMore;

  static const _cardWidth = 158.0;

  @override
  Widget build(BuildContext context) {
    final height = _cardWidth + costumeCardTextHeight(context) + 4;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.section - 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.page),
            child: SectionHeader(
              title: title,
              subtitle: '${costumes.length} kostum',
              actionLabel: costumes.length > 2 ? 'Lihat semua' : null,
              onAction: onSeeMore,
            ),
          ),
          SizedBox(
            height: height,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.page),
              itemCount: costumes.length,
              separatorBuilder: (_, _) => const SizedBox(width: 12),
              itemBuilder: (context, i) => SizedBox(
                width: _cardWidth,
                child: Align(
                  alignment: Alignment.topCenter,
                  child: CostumeCard(
                    costume: costumes[i],
                    onTap: () => context.push('/detail/${costumes[i].id}'),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
