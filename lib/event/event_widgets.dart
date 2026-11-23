import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'catalog.dart';
import 'catalog_controller.dart';
import 'catalog_repository.dart';
import 'contact_service.dart';
import '../widgets/costume_card.dart';

class EventPreferences {
  const EventPreferences({
    required this.themeMode,
    required this.setTheme,
    required this.reset,
  });
  final ThemeMode themeMode;
  final ValueChanged<ThemeMode> setTheme;
  final VoidCallback reset;
}

class EventScaffold extends StatelessWidget {
  const EventScaffold({
    super.key,
    required this.title,
    required this.child,
    this.back = true,
    this.bottomNavigationBar,
  });
  final String title;
  final Widget child;
  final bool back;
  final Widget? bottomNavigationBar;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
      leading: back
          ? IconButton(
              tooltip: 'Kembali',
              icon: const Icon(Icons.arrow_back),
              onPressed: () =>
                  context.canPop() ? context.pop() : context.go('/home'),
            )
          : null,
      automaticallyImplyLeading: false,
      actions: const [EventMenu()],
    ),
    bottomNavigationBar: bottomNavigationBar,
    body: SafeArea(
      child: Column(
        children: [
          const EventNotice(),
          Expanded(child: child),
        ],
      ),
    ),
  );
}

class EventMenu extends StatelessWidget {
  const EventMenu({super.key});
  @override
  Widget build(BuildContext context) => PopupMenuButton<String>(
    tooltip: 'Tema dan sesi uji',
    onSelected: (value) {
      final preferences = context.read<EventPreferences>();
      if (value == 'reset') {
        preferences.reset();
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Sesi uji direset.')));
      } else {
        preferences.setTheme(ThemeMode.values.byName(value));
      }
    },
    itemBuilder: (context) => [
      const PopupMenuItem(value: 'system', child: Text('Tema sistem')),
      const PopupMenuItem(value: 'light', child: Text('Tema terang')),
      const PopupMenuItem(value: 'dark', child: Text('Tema gelap')),
      const PopupMenuDivider(),
      const PopupMenuItem(value: 'reset', child: Text('Reset sesi uji')),
    ],
  );
}

class EventNotice extends StatelessWidget {
  const EventNotice({super.key, this.showMenu = false});
  final bool showMenu;
  @override
  Widget build(BuildContext context) {
    final illustrative = context
        .watch<CatalogController>()
        .snapshot
        ?.illustrative;
    final colors = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      color: Theme.of(context).brightness == Brightness.dark
          ? const Color(0xFF34264A)
          : const Color(0xFFF0E8FC),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              'Versi uji • Konfirmasi stok ke toko.'
              '${illustrative == true ? '\nData ilustratif • Harga simulasi' : ''}',
              style: Theme.of(context).textTheme.bodySmall
                  ?.copyWith(color: colors.onSurface),
            ),
          ),
          if (showMenu) const EventMenu(),
        ],
      ),
    );
  }
}

class CatalogBody extends StatelessWidget {
  const CatalogBody({super.key, required this.builder});
  final Widget Function(BuildContext, CatalogSnapshot) builder;
  @override
  Widget build(BuildContext context) {
    final catalog = context.watch<CatalogController>();
    switch (catalog.status) {
      case CatalogStatus.loading:
        return const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Memuat katalog lokal…'),
            ],
          ),
        );
      case CatalogStatus.failed:
        return EventMessage(
          icon: Icons.error_outline,
          title: catalog.failure == CatalogFailure.invalidData
              ? 'Data katalog tidak valid'
              : 'Katalog gagal dibaca',
          message: catalog.failure == CatalogFailure.invalidData
              ? 'Format data atau gambar lokal bermasalah. Minta pengelola memvalidasi snapshot.'
              : 'Berkas katalog lokal tidak dapat dibaca. Ini bukan hasil pencarian kosong.',
          action: OutlinedButton(
            onPressed: catalog.initialize,
            child: const Text('Coba lagi'),
          ),
        );
      case CatalogStatus.ready:
        return builder(context, catalog.snapshot!);
    }
  }
}

class EventMessage extends StatelessWidget {
  const EventMessage({
    super.key,
    required this.title,
    required this.message,
    this.icon = Icons.search_off,
    this.action,
  });
  final String title;
  final String message;
  final IconData icon;
  final Widget? action;
  @override
  Widget build(BuildContext context) => Center(
    child: SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 40),
          const SizedBox(height: 12),
          Text(
            title,
            style: Theme.of(context).textTheme.titleMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(message, textAlign: TextAlign.center),
          if (action != null)
            Padding(padding: const EdgeInsets.only(top: 12), child: action),
        ],
      ),
    ),
  );
}

class CatalogImage extends StatelessWidget {
  const CatalogImage(
    this.path, {
    super.key,
    required this.label,
    this.fit = BoxFit.cover,
  });
  final String path;
  final String label;
  final BoxFit fit;
  @override
  Widget build(BuildContext context) => Image.asset(
    path,
    fit: fit,
    semanticLabel: label,
    errorBuilder: (context, error, stack) => Container(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      padding: const EdgeInsets.all(8),
      child: const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.broken_image_outlined),
            Text('Gambar gagal dimuat', textAlign: TextAlign.center),
          ],
        ),
      ),
    ),
  );
}

class EventProductCard extends StatelessWidget {
  const EventProductCard({
    super.key,
    required this.product,
    required this.snapshot,
  });
  final CatalogProduct product;
  final CatalogSnapshot snapshot;
  @override
  Widget build(BuildContext context) => CostumeCard.catalog(
    product: product,
    snapshot: snapshot,
    onTap: () {
      FocusScope.of(context).unfocus();
      context.push('/detail/${product.id}');
    },
  );
}

class InfoSection extends StatelessWidget {
  const InfoSection(this.title, this.value, {super.key});
  final String title;
  final String? value;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 18),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.titleSmall
              ?.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 4),
        Text(value ?? 'Belum diinformasikan'),
      ],
    ),
  );
}

Future<void> showContactPreview(BuildContext context, ContactDraft draft) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => ContactPreview(draft: draft),
    );

class ContactPreview extends StatefulWidget {
  const ContactPreview({super.key, required this.draft});
  final ContactDraft draft;
  @override
  State<ContactPreview> createState() => _ContactPreviewState();
}

class _ContactPreviewState extends State<ContactPreview> {
  bool _opening = false;
  String? _failure;
  Future<void> _open() async {
    final uri = widget.draft.whatsappUri;
    if (uri == null || _opening) return;
    setState(() {
      _opening = true;
      _failure = null;
    });
    var opened = false;
    try {
      opened = await context.read<ContactGateway>().open(uri);
    } catch (_) {
      /* Keep draft available for copying. */
    }
    if (mounted) {
      setState(() {
        _opening = false;
        if (!opened) _failure = 'WhatsApp tidak dapat dibuka. Periksa aplikasi/koneksi, atau salin ringkasan dan kontak di bawah.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final draft = widget.draft;
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        20,
        20,
        20,
        20 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Ringkasan pertanyaan',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 12),
          SelectableText(draft.message, key: const ValueKey('contact-message')),
          const SizedBox(height: 16),
          Text(
            draft.illustrative
                ? 'Kontak nonaktif: ini data ilustratif, tanpa nomor toko nyata.'
                : draft.canContact
                ? 'Membuka WhatsApp tidak mengirim pesan otomatis. Jika WhatsApp atau internet tidak tersedia, salin ringkasan dan kontak. Toko tetap perlu mengonfirmasi.'
                : 'Kontak bisnis berizin belum diinformasikan. Pengelola perlu melengkapi katalog.',
          ),
          if (draft.canContact)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: SelectableText(draft.store.whatsapp!),
            ),
          if (_failure != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(_failure!, key: const ValueKey('contact-failure')),
            ),
          const SizedBox(height: 16),
          FilledButton.icon(
            key: const ValueKey('open-whatsapp'),
            onPressed: draft.canContact && !_opening ? _open : null,
            icon: const Icon(Icons.open_in_new),
            label: Text(_opening ? 'Membuka…' : 'Buka WhatsApp toko'),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: draft.message));
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Ringkasan disalin.')),
                );
              }
            },
            icon: const Icon(Icons.copy),
            label: const Text('Salin ringkasan'),
          ),
          if (draft.canContact)
            TextButton(
              onPressed: () async {
                await Clipboard.setData(
                  ClipboardData(text: draft.store.whatsapp!),
                );
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Kontak bisnis disalin.')),
                  );
                }
              },
              child: const Text('Salin kontak bisnis'),
            ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Tutup'),
          ),
        ],
      ),
    );
  }
}
