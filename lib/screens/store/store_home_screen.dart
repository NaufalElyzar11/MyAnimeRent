import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../models/store_admin.dart';
import '../../providers/store_admin_provider.dart';
import '../rental_history_screen.dart' show StatusChip;
import 'store_calendar_tab.dart';
import 'store_catalog_tab.dart';

/// Tab "Toko": kotak permintaan dan kalender untuk owner/staf toko.
class StoreHomeScreen extends StatefulWidget {
  const StoreHomeScreen({super.key});

  @override
  State<StoreHomeScreen> createState() => _StoreHomeScreenState();
}

class _StoreHomeScreenState extends State<StoreHomeScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final p = context.read<StoreAdminProvider>();
      if (!p.hasStores) {
        p.loadStores();
      } else {
        p.loadRequests();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<StoreAdminProvider>();
    final store = provider.selected;

    if (store == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Toko Saya')),
        body: Center(
          child: provider.loadingStores
              ? const CircularProgressIndicator()
              : Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(provider.error ?? 'Akun ini belum terhubung ke toko mana pun.', textAlign: TextAlign.center),
                      const SizedBox(height: 12),
                      OutlinedButton(onPressed: provider.loadStores, child: const Text('Muat ulang')),
                    ],
                  ),
                ),
        ),
      );
    }

    final open = provider.openCount;
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: _StoreSwitcher(stores: provider.stores, selected: store),
          actions: [
            IconButton(
              tooltip: 'Profil toko',
              icon: const Icon(Icons.storefront_outlined),
              onPressed: () => context.push('/store/profile?store=${store.id}'),
            ),
          ],
          bottom: TabBar(
            tabs: [
              Tab(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Permintaan'),
                    if (open > 0) ...[
                      const SizedBox(width: 6),
                      Badge(label: Text('$open')),
                    ],
                  ],
                ),
              ),
              const Tab(text: 'Kalender'),
              const Tab(text: 'Katalog'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            store.canOrders
                ? const _RequestsTab()
                : const _NoPermission(text: 'Akun Anda tidak punya izin mengelola permintaan di toko ini.'),
            (store.canCalendar || store.canOrders)
                ? StoreCalendarTab(key: ValueKey(store.id), store: store)
                : const _NoPermission(text: 'Akun Anda tidak punya izin membuka kalender toko ini.'),
            store.canCatalog
                ? StoreCatalogTab(key: ValueKey('katalog-${store.id}'), store: store)
                : const _NoPermission(text: 'Akun Anda tidak punya izin mengelola katalog toko ini.'),
          ],
        ),
      ),
    );
  }
}

class _StoreSwitcher extends StatelessWidget {
  const _StoreSwitcher({required this.stores, required this.selected});
  final List<MyStore> stores;
  final MyStore selected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final title = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(selected.name, maxLines: 1, overflow: TextOverflow.ellipsis),
        Text(
          [selected.isOwner ? 'Owner' : 'Staf', if (selected.status != 'published') 'belum terbit'].join(' · '),
          style: theme.textTheme.bodySmall,
        ),
      ],
    );
    if (stores.length < 2) return title;
    return PopupMenuButton<String>(
      tooltip: 'Ganti toko',
      onSelected: (id) => context.read<StoreAdminProvider>().select(id),
      itemBuilder: (_) => [
        for (final s in stores) CheckedPopupMenuItem(value: s.id, checked: s.id == selected.id, child: Text(s.name)),
      ],
      child: Row(mainAxisSize: MainAxisSize.min, children: [Flexible(child: title), const Icon(Icons.arrow_drop_down)]),
    );
  }
}

class _NoPermission extends StatelessWidget {
  const _NoPermission({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) =>
      Center(child: Padding(padding: const EdgeInsets.all(24), child: Text(text, textAlign: TextAlign.center)));
}

class _RequestsTab extends StatelessWidget {
  const _RequestsTab();

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<StoreAdminProvider>();
    final theme = Theme.of(context);
    final items = provider.requests;

    return Column(
      children: [
        SizedBox(
          height: 52,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            children: [
              for (final f in RequestFilter.values)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text('${f.label} (${provider.countFor(f)})'),
                    selected: provider.filter == f,
                    onSelected: (_) => provider.setFilter(f),
                  ),
                ),
            ],
          ),
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: provider.loadRequests,
            child: provider.loadingRequests && items.isEmpty
                ? ListView(children: const [SizedBox(height: 120), Center(child: CircularProgressIndicator())])
                : items.isEmpty
                    ? ListView(
                        padding: const EdgeInsets.all(32),
                        children: [
                          const SizedBox(height: 40),
                          Icon(Icons.inbox_outlined, size: 56, color: theme.colorScheme.primary),
                          const SizedBox(height: 12),
                          Text(
                            provider.error ??
                                (provider.filter == RequestFilter.needsAnswer
                                    ? 'Tidak ada permintaan yang menunggu jawaban.'
                                    : 'Belum ada permintaan di sini.'),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
                        itemCount: items.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 8),
                        itemBuilder: (_, i) => _StoreRequestTile(request: items[i]),
                      ),
          ),
        ),
      ],
    );
  }
}

class _StoreRequestTile extends StatelessWidget {
  const _StoreRequestTile({required this.request});
  final StoreRequest request;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final r = request;
    final fmt = DateFormat('d MMM', 'id_ID');
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () async {
          await context.push('/store/requests/${r.id}');
          if (context.mounted) context.read<StoreAdminProvider>().loadRequests();
        },
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: SizedBox(
                  width: 56,
                  height: 56,
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
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            r.productTitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                          ),
                        ),
                        StatusChip(status: r.status, storeView: true),
                      ],
                    ),
                    Text(
                      '${r.size == null ? '' : 'Ukuran ${r.size} · '}${fmt.format(r.rentStart)} – ${fmt.format(r.rentEnd)} (${r.days} hari)',
                      style: theme.textTheme.bodySmall,
                    ),
                    Text(
                      '${r.renterName ?? 'Penyewa'} · ${r.code}',
                      style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                    ),
                    if (r.lastMessageAt != null)
                      Text(
                        'Pesan terakhir ${DateFormat('d MMM HH:mm', 'id_ID').format(r.lastMessageAt!.toLocal())}',
                        style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
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
