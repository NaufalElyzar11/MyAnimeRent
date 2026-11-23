import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../widgets/costume_grid.dart';
import 'catalog_controller.dart';
import 'event_widgets.dart';

class EventFavoritesBody extends StatelessWidget {
  const EventFavoritesBody({super.key});
  @override
  Widget build(BuildContext context) => CatalogBody(
    builder: (context, snapshot) {
      final favorites = context.watch<CatalogController>().favorites;
      if (favorites.isEmpty) {
        return EventMessage(
          icon: Icons.favorite_border_rounded,
          title: 'Favorit masih kosong',
          message: 'Tekan ikon hati pada kostum untuk menyimpannya selama sesi uji ini.',
          action: FilledButton.icon(
            onPressed: () => context.go('/search'),
            icon: const Icon(Icons.explore_outlined),
            label: const Text('Jelajahi kostum'),
          ),
        );
      }
      return ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('Favorit lokal • Hanya untuk sesi ini, tanpa akun'),
          const SizedBox(height: 12),
          CostumeGrid(
            children: [
              for (final product in favorites)
                EventProductCard(product: product, snapshot: snapshot),
            ],
          ),
        ],
      );
    },
  );
}

class EventGuestBody extends StatelessWidget {
  const EventGuestBody({super.key});
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final preferences = context.watch<EventPreferences>();
    final favorites = context.watch<CatalogController>().favorites.length;
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const Align(
          child: CircleAvatar(
            radius: 46,
            child: Icon(Icons.person_outline, size: 48),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'Pengunjung',
          textAlign: TextAlign.center,
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        const Text('Sesi uji tanpa akun', textAlign: TextAlign.center),
        const SizedBox(height: 24),
        Card(
          child: ListTile(
            contentPadding: const EdgeInsets.all(16),
            leading: const Icon(Icons.favorite_outline),
            title: const Text('Favorit lokal'),
            subtitle: Text('$favorites kostum disimpan selama sesi ini'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.go('/favorites-local'),
          ),
        ),
        const SizedBox(height: 16),
        Text('Pengaturan tema', style: theme.textTheme.titleMedium),
        const SizedBox(height: 8),
        for (final option in {
          ThemeMode.system: 'Ikuti sistem',
          ThemeMode.light: 'Terang',
          ThemeMode.dark: 'Gelap',
        }.entries)
          ListTile(
            key: ValueKey('theme-choice-${option.key.name}'),
            title: Text(option.value),
            trailing: preferences.themeMode == option.key
                ? const Icon(Icons.check)
                : null,
            onTap: () => preferences.setTheme(option.key),
          ),
        const SizedBox(height: 16),
        const Card(
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'Akun dan riwayat sewa tetap tersedia di aplikasi utama. Pada versi uji ini, favorit dan pilihan kostum bersifat sementara. Pemesanan perlu dikonfirmasi ke toko.',
            ),
          ),
        ),
        const SizedBox(height: 16),
        OutlinedButton.icon(
          key: const ValueKey('reset-session'),
          onPressed: preferences.reset,
          icon: const Icon(Icons.restart_alt),
          label: const Text('Reset sesi uji'),
        ),
      ],
    );
  }
}

class EventSeriesScreen extends StatefulWidget {
  const EventSeriesScreen({super.key, required this.series});
  final String series;
  @override
  State<EventSeriesScreen> createState() => _EventSeriesScreenState();
}

class _EventSeriesScreenState extends State<EventSeriesScreen> {
  int _visible = 12;
  @override
  Widget build(BuildContext context) => EventScaffold(
    title: widget.series,
    child: CatalogBody(
      builder: (context, snapshot) {
        final products =
            snapshot.products.where((p) => p.series == widget.series).toList()
              ..sort((a, b) => a.id.compareTo(b.id));
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text('${products.length} kostum'),
            const SizedBox(height: 12),
            CostumeGrid(
              children: [
                for (final p in products.take(_visible))
                  EventProductCard(product: p, snapshot: snapshot),
              ],
            ),
            if (products.isEmpty)
              const EventMessage(
                title: 'Tidak ada kostum di seri ini',
                message: 'Coba seri lain dari beranda.',
              ),
            if (_visible < products.length)
              OutlinedButton(
                onPressed: () => setState(() => _visible += 12),
                child: const Text('Tampilkan lagi'),
              ),
          ],
        );
      },
    ),
  );
}
