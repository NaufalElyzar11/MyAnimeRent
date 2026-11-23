import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'catalog_controller.dart';
import 'contact_service.dart';
import 'event_widgets.dart';
import '../widgets/app_shell.dart';
import '../widgets/costume_grid.dart';

export 'event_search_screen.dart';

class EventShell extends StatelessWidget {
  const EventShell({super.key, required this.shell});
  final StatefulNavigationShell shell;
  @override
  Widget build(BuildContext context) => AppShell(
    navigationShell: shell,
    child: Column(
      children: [
        const EventNotice(showMenu: true),
        Expanded(child: shell),
      ],
    ),
  );
}

class EventProductScreen extends StatefulWidget {
  const EventProductScreen({super.key, required this.productId});
  final String productId;
  @override
  State<EventProductScreen> createState() => _EventProductScreenState();
}

class _EventProductScreenState extends State<EventProductScreen> {
  String? _size;
  DateTimeRange? _dates;
  int _imageIndex = 0;

  Future<void> _chooseDates() async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final result = await showDateRangePicker(
      context: context,
      firstDate: today,
      lastDate: today.add(const Duration(days: 730)),
      initialDateRange: _dates,
      helpText: 'Tanggal untuk ditanyakan',
      saveText: 'Gunakan tanggal',
    );
    if (result != null && mounted) setState(() => _dates = result);
  }

  @override
  Widget build(BuildContext context) => EventScaffold(
    title: 'Detail kostum',
    child: CatalogBody(
      builder: (context, snapshot) {
        final matches = snapshot.products.where(
          (p) => p.id == widget.productId,
        );
        if (matches.isEmpty) {
          return const EventMessage(
            title: 'Kostum tidak ditemukan',
            message: 'ID ini tidak ada di katalog lokal. Kembali untuk mencari kostum lain.',
          );
        }
        final p = matches.first;
        final store = snapshot.store(p.storeId);
        final catalog = context.watch<CatalogController>();
        return ListView(
          key: const PageStorageKey('event-product'),
          padding: const EdgeInsets.all(16),
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: SizedBox(
                height: 280,
                child: PageView.builder(
                  itemCount: p.imageAssets.length,
                  onPageChanged: (index) => setState(() => _imageIndex = index),
                  itemBuilder: (context, index) => CatalogImage(
                    p.imageAssets[index],
                    label: '${p.name}, gambar ${index + 1}',
                    fit: BoxFit.contain,
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                '${snapshot.illustrative ? 'Ilustrasi' : 'Galeri'} ${_imageIndex + 1} / ${p.imageAssets.length}',
                textAlign: TextAlign.center,
              ),
            ),
            Text(
              p.name,
              style: Theme.of(context).textTheme.headlineSmall
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
            Text('${p.character} · ${p.series}'),
            const SizedBox(height: 12),
            Text(
              priceLabel(p.price),
              style: Theme.of(context).textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
            if (snapshot.illustrative)
              const Text('Harga dan deposit di sini adalah simulasi.'),
            const SizedBox(height: 12),
            InfoSection(
              'Deposit terpisah',
              p.depositIdr == null ? null : rupiah(p.depositIdr!),
            ),
            OutlinedButton.icon(
              key: const ValueKey('detail-favorite'),
              onPressed: () => catalog.toggleFavorite(p.id),
              icon: Icon(
                catalog.isFavorite(p.id)
                    ? Icons.favorite
                    : Icons.favorite_border,
              ),
              label: Text(
                catalog.isFavorite(p.id)
                    ? 'Hapus dari favorit lokal'
                    : 'Simpan favorit lokal',
              ),
            ),
            OutlinedButton.icon(
              key: const ValueKey('store-profile'),
              onPressed: () => context.push('/store_detail/${store.id}'),
              icon: const Icon(Icons.storefront_outlined),
              label: Text(
                '${store.name} · ${snapshot.cityName(store.cityCode)}',
              ),
            ),
            const SizedBox(height: 18),
            Text('Ukuran', style: Theme.of(context).textTheme.titleSmall),
            if (p.sizes.isEmpty)
              const Text('Belum diinformasikan')
            else
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  for (final size in p.sizes)
                    ChoiceChip(
                      label: Text(size),
                      selected: _size == size,
                      onSelected: (selected) =>
                          setState(() => _size = selected ? size : null),
                      materialTapTargetSize: MaterialTapTargetSize.padded,
                    ),
                ],
              ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _chooseDates,
              icon: const Icon(Icons.calendar_month_outlined),
              label: Text(
                _dates == null
                    ? 'Tanggal pertanyaan (opsional)'
                    : '${dateLabel(_dates!.start)} – ${dateLabel(_dates!.end)}',
              ),
            ),
            if (_dates != null)
              TextButton(
                onPressed: () => setState(() => _dates = null),
                child: const Text('Hapus tanggal'),
              ),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text(
                'Tanggal hanya konteks pertanyaan. Ketersediaan dan ketentuan sewa perlu dikonfirmasi ke toko.',
              ),
            ),
            FilledButton.icon(
              key: const ValueKey('contact-preview'),
              onPressed: () => showContactPreview(
                context,
                ContactDraft(
                  product: p,
                  store: store,
                  illustrative: snapshot.illustrative,
                  size: _size,
                  startDate: _dates?.start,
                  endDate: _dates?.end,
                ),
              ),
              icon: const Icon(Icons.chat_bubble_outline),
              label: Text(
                snapshot.illustrative
                    ? 'Lihat ringkasan (simulasi)'
                    : 'Siapkan pertanyaan ke toko',
              ),
            ),
            const SizedBox(height: 24),
            InfoSection('Deskripsi', p.description),
            InfoSection('Ukuran dalam cm', p.sizeNotes),
            InfoSection(
              'Kelengkapan paket',
              p.packageContents.isEmpty ? null : p.packageContents.join('\n'),
            ),
            InfoSection('Kebijakan kostum', p.policies),
            InfoSection('Kebijakan toko', store.policies),
            InfoSection(
              'Waktu verifikasi katalog',
              verifiedLabel(p.verifiedAt),
            ),
          ],
        );
      },
    ),
  );
}

class EventStoreScreen extends StatefulWidget {
  const EventStoreScreen({super.key, required this.storeId});
  final String storeId;
  @override
  State<EventStoreScreen> createState() => _EventStoreScreenState();
}

class _EventStoreScreenState extends State<EventStoreScreen> {
  int _visible = 12;
  @override
  Widget build(BuildContext context) => EventScaffold(
    title: 'Profil toko',
    child: CatalogBody(
      builder: (context, snapshot) {
        final stores = snapshot.stores.where((s) => s.id == widget.storeId);
        if (stores.isEmpty) {
          return const EventMessage(
            title: 'Toko tidak ditemukan',
            message: 'ID ini tidak ada di katalog lokal.',
          );
        }
        final store = stores.first;
        final products =
            snapshot.products.where((p) => p.storeId == store.id).toList()
              ..sort((a, b) => a.id.compareTo(b.id));
        final contact = !snapshot.illustrative && store.contactConsent
            ? store.whatsapp
            : null;
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Align(
              alignment: Alignment.centerLeft,
              child: CircleAvatar(
                radius: 28,
                child: Icon(Icons.storefront, size: 30),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              store.name,
              style: Theme.of(context).textTheme.headlineSmall
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
            Text(snapshot.cityName(store.cityCode)),
            const SizedBox(height: 20),
            InfoSection('Tentang toko', store.description),
            InfoSection('Kebijakan toko', store.policies),
            InfoSection(
              'Waktu verifikasi katalog toko',
              verifiedLabel(store.verifiedAt),
            ),
            InfoSection(
              'Kontak bisnis',
              snapshot.illustrative
                  ? 'Nonaktif • Toko ilustratif, tanpa nomor nyata.'
                  : contact,
            ),
            if (contact != null) ...[
              OutlinedButton.icon(
                onPressed: () async {
                  await Clipboard.setData(ClipboardData(text: contact));
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Kontak bisnis disalin.')),
                    );
                  }
                },
                icon: const Icon(Icons.copy),
                label: const Text('Salin kontak bisnis'),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  'Pilih kostum di bawah untuk menyiapkan pertanyaan WhatsApp.',
                ),
              ),
            ],
            const SizedBox(height: 8),
            Text(
              'Katalog toko · ${products.length} kostum',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            CostumeGrid(
              children: [
                for (final product in products.take(_visible))
                  EventProductCard(product: product, snapshot: snapshot),
              ],
            ),
            if (products.isEmpty)
              const Text('Belum ada kostum di katalog toko ini.'),
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

class EventStoresScreen extends StatelessWidget {
  const EventStoresScreen({super.key});
  @override
  Widget build(BuildContext context) => EventScaffold(
    title: 'Toko di katalog',
    child: CatalogBody(
      builder: (context, snapshot) => ListView(
        padding: const EdgeInsets.all(16),
        children: [
          for (final store in snapshot.stores)
            Card(
              child: ListTile(
                contentPadding: const EdgeInsets.all(16),
                leading: const Icon(Icons.storefront),
                title: Text(store.name),
                subtitle: Text(snapshot.cityName(store.cityCode)),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.push('/store_detail/${store.id}'),
              ),
            ),
          if (snapshot.stores.isEmpty)
            const Text('Belum ada toko di snapshot ini.'),
        ],
      ),
    ),
  );
}

class EventUnavailableScreen extends StatelessWidget {
  const EventUnavailableScreen({super.key});
  @override
  Widget build(BuildContext context) => EventScaffold(
    title: 'Versi uji event',
    child: EventMessage(
      icon: Icons.lock_outline,
      title: 'Halaman tidak tersedia pada versi uji',
      message: 'Versi ini menyediakan katalog publik. Akun, admin, rental, dan perubahan data cloud dinonaktifkan.',
      action: FilledButton(
        onPressed: () => context.go('/home'),
        child: const Text('Ke beranda'),
      ),
    ),
  );
}
