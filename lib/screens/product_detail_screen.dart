import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/availability.dart';
import '../models/costume.dart';
import '../providers/auth_provider.dart';
import '../providers/costume_provider.dart';
import '../providers/rental_provider.dart';
import '../providers/wishlist_provider.dart';
import '../services/database_service.dart';
import '../services/supabase_service.dart';
import '../widgets/expandable_calendar_view.dart';

final _rupiah = NumberFormat.decimalPattern('id_ID');
String rupiah(num v) => 'Rp ${_rupiah.format(v)}';

/// Detail kostum + cek tanggal + ajukan permintaan sewa (tanpa WhatsApp).
class ProductDetailScreen extends StatefulWidget {
  final String costumeId;
  const ProductDetailScreen({super.key, required this.costumeId});

  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen> {
  final _db = DatabaseService();
  Costume? _costume;
  ProductAvailability? _availability;
  String? _error;
  bool _isLoading = true;
  bool _isSending = false;
  bool _checkingDates = false;
  CostumeVariant? _variant;
  DateTime? _startDate;
  DateTime? _endDate; // inklusif
  String? _dateStatus; // booked / no_schedule / not_rentable (hasil cek server)
  String? _idempotencyKey;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final costume = await context.read<CostumeProvider>().getCostumeById(widget.costumeId, refresh: true);
      ProductAvailability? availability;
      if (costume != null) availability = await _db.getAvailability(costume.id);
      if (!mounted) return;
      setState(() {
        _costume = costume;
        _availability = availability;
        _variant = costume?.variants.where((v) => availability?.forVariant(v.id)?.rentable ?? true).firstOrNull ??
            costume?.variants.firstOrNull;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  VariantAvailability? get _variantAvailability => _availability?.forVariant(_variant?.id);

  int get _days => (_startDate == null || _endDate == null) ? 0 : _endDate!.difference(_startDate!).inDays + 1;

  void _resetDates() {
    _startDate = null;
    _endDate = null;
    _dateStatus = null;
    _idempotencyKey = null;
  }

  Future<void> _setRange(DateTime start, DateTime end) async {
    setState(() {
      _startDate = start;
      _endDate = end;
      _dateStatus = null;
      _idempotencyKey = null;
      _checkingDates = true;
    });
    try {
      final check = await _db.getAvailability(
        widget.costumeId,
        rentStart: start,
        rentEndExclusive: DateTime(end.year, end.month, end.day + 1),
        days: 1,
      );
      if (!mounted || _startDate != start || _endDate != end) return;
      setState(() => _dateStatus = check?.forVariant(_variant?.id)?.status);
    } catch (_) {
      // Cek gagal (jaringan): server tetap memeriksa saat toko mengonfirmasi.
    }
    if (mounted) setState(() => _checkingDates = false);
  }

  Future<void> _pickCustomRange() async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final range = await showDateRangePicker(
      context: context,
      firstDate: today,
      lastDate: today.add(const Duration(days: 365)),
      helpText: 'Pilih tanggal sewa',
    );
    if (range == null || !mounted) return;
    final days = range.end.difference(range.start).inDays + 1;
    if (days > 60) {
      _snack('Maksimal 60 hari per permintaan.', error: true);
      return;
    }
    final booked = _variantAvailability?.bookedDateKeys.toSet() ?? const <String>{};
    for (var d = range.start; !d.isAfter(range.end); d = DateTime(d.year, d.month, d.day + 1)) {
      if (booked.contains(dateKey(d))) {
        _snack('Sebagian tanggal itu sudah dipesan. Pilih tanggal lain.', error: true);
        return;
      }
    }
    await _setRange(range.start, range.end);
  }

  void _snack(String msg, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: error ? Colors.red.shade700 : null),
    );
  }

  Future<void> _toggleWishlist() async {
    final result = await context.read<WishlistProvider>().toggleWishlist(widget.costumeId);
    if (!mounted) return;
    if (result == null) {
      context.push('/login?from=${Uri.encodeComponent('/detail/${widget.costumeId}')}');
      return;
    }
    _snack(result ? 'Disimpan ke wishlist' : 'Dihapus dari wishlist');
  }

  Future<void> _contactStore(Costume c) async {
    final phone = c.storeWhatsapp?.replaceAll('+', '');
    if (phone == null || phone.isEmpty) return;
    _db.recordContactClick(c.id);
    final text = Uri.encodeComponent('Halo ${c.storeName}, saya tertarik menyewa "${c.name}" (MyAnimeRent).');
    await launchUrl(Uri.parse('https://wa.me/$phone?text=$text'), mode: LaunchMode.externalApplication);
  }

  void _startRequest() {
    final auth = context.read<AuthProvider>();
    if (!auth.isLoggedIn) {
      context.push('/login?from=${Uri.encodeComponent('/detail/${widget.costumeId}')}');
      return;
    }
    if (_dateStatus == 'booked') {
      _snack('Ukuran ini sudah dipesan pada tanggal tersebut. Pilih tanggal atau ukuran lain.', error: true);
      return;
    }
    _idempotencyKey ??= newOperationId();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (sheetContext) => _RequestSheet(
        costume: _costume!,
        size: _variant?.size,
        start: _startDate!,
        end: _endDate!,
        hasPhone: (auth.user?.phoneNumber ?? '').isNotEmpty,
        sending: _isSending,
        onSubmit: (note, consent) async {
          Navigator.pop(sheetContext);
          await _send(note, consent);
        },
      ),
    );
  }

  Future<void> _send(String note, bool consent) async {
    setState(() => _isSending = true);
    try {
      final created = await context.read<RentalProvider>().createRequest(
            idempotencyKey: _idempotencyKey!,
            productId: _costume!.id,
            variantId: _variant?.id,
            startDate: _startDate!,
            endDate: _endDate!,
            note: note,
            contactConsent: consent,
          );
      if (!mounted) return;
      setState(_resetDates);
      _snack('Permintaan ${created.requestCode} terkirim. Toko akan memberi kabar di aplikasi.');
      context.push('/requests/${created.requestId}');
    } on ApiException catch (e) {
      if (!mounted) return;
      // Gangguan jaringan: kunci yang sama dipakai lagi agar tidak terkirim dua kali.
      if (!e.isNetwork) _idempotencyKey = null;
      _snack(e.message, error: true);
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (_isLoading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    final costume = _costume;
    if (costume == null) {
      return Scaffold(
        appBar: AppBar(),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(_error ?? 'Kostum ini tidak tersedia atau sudah ditarik toko.', textAlign: TextAlign.center),
                const SizedBox(height: 12),
                if (_error != null) OutlinedButton(onPressed: _load, child: const Text('Coba lagi')),
              ],
            ),
          ),
        ),
      );
    }

    final wishlisted = context.watch<WishlistProvider>().isItemInWishlist(costume.id);
    final availability = _availability;
    final variantAv = _variantAvailability;
    final rangeDays = costume.durationDays ?? 3;
    final canRequest = _startDate != null && !_isSending && _dateStatus != 'booked' && (variantAv?.rentable ?? true);

    return Scaffold(
      body: Stack(
        children: [
          RefreshIndicator(
            onRefresh: _load,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    height: 380,
                    child: costume.imageUrls.isEmpty
                        ? Container(
                            color: theme.colorScheme.surfaceContainerHighest,
                            child: const Center(child: Icon(Icons.image_not_supported, size: 60)),
                          )
                        : PageView.builder(
                            itemCount: costume.imageUrls.length,
                            itemBuilder: (_, i) => CachedNetworkImage(
                              imageUrl: costume.imageUrls[i],
                              fit: BoxFit.cover,
                              width: double.infinity,
                              errorWidget: (_, _, _) => Container(
                                color: theme.colorScheme.surfaceContainerHighest,
                                child: const Icon(Icons.image_not_supported, size: 60),
                              ),
                            ),
                          ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(costume.name, style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 4),
                        Text(
                          [costume.character, costume.anime].where((s) => s.isNotEmpty && s != 'Lainnya').join(' · '),
                          style: theme.textTheme.titleSmall?.copyWith(color: theme.colorScheme.primary),
                        ),
                        const SizedBox(height: 12),
                        if (costume.hasPrice)
                          Text(
                            '${rupiah(costume.price)} / ${costume.durationDays} hari',
                            style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                          )
                        else
                          Text('Harga belum diinformasikan', style: theme.textTheme.titleMedium),
                        if (costume.depositIdr > 0)
                          Text('Deposit ${rupiah(costume.depositIdr)} (dikembalikan setelah kostum kembali)',
                              style: theme.textTheme.bodySmall),
                        const SizedBox(height: 16),
                        _StoreBox(costume: costume, onContact: () => _contactStore(costume)),
                        if (costume.description.isNotEmpty) ...[
                          const SizedBox(height: 16),
                          Text('Deskripsi', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                          const SizedBox(height: 4),
                          Text(costume.description, style: theme.textTheme.bodyLarge),
                        ],
                        if (costume.packageContents.isNotEmpty) ...[
                          const SizedBox(height: 16),
                          Text('Isi paket', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                          const SizedBox(height: 4),
                          for (final item in costume.packageContents) Text('• $item'),
                        ],
                        const SizedBox(height: 20),
                        Text('Pilih ukuran', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        if (costume.variants.isEmpty)
                          const Text('Ukuran belum diinformasikan')
                        else
                          Wrap(
                            spacing: 8,
                            runSpacing: 4,
                            children: [
                              for (final v in costume.variants)
                                ChoiceChip(
                                  label: Text(v.size),
                                  selected: _variant?.id == v.id,
                                  onSelected: (availability?.forVariant(v.id)?.rentable ?? true)
                                      ? (_) => setState(() {
                                            _variant = v;
                                            _resetDates();
                                          })
                                      : null,
                                ),
                            ],
                          ),
                        if (costume.sizeNotes != null && costume.sizeNotes!.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Text(costume.sizeNotes!, style: theme.textTheme.bodySmall),
                        ],
                        if (variantAv != null && !variantAv.rentable)
                          Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text('Ukuran ini sedang tidak disewakan.', style: TextStyle(color: Colors.red.shade700)),
                          ),
                        const SizedBox(height: 24),
                        Text('Pilih tanggal sewa', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 6),
                        _CalendarNote(availability: availability),
                        const SizedBox(height: 8),
                        ExpandableCalendarView(
                          bookedDates: variantAv?.bookedDateKeys ?? const [],
                          selectedStartDate: _startDate,
                          selectedEndDate: _endDate,
                          rangeDays: rangeDays,
                          onDateRangeSelected: _setRange,
                          onSelectionInvalid: (msg) => _snack(msg, error: true),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                _startDate == null
                                    ? 'Ketuk tanggal mulai (paket $rangeDays hari)'
                                    : '${DateFormat('d MMM', 'id_ID').format(_startDate!)} – '
                                        '${DateFormat('d MMM yyyy', 'id_ID').format(_endDate!)} ($_days hari)',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: _startDate != null ? theme.colorScheme.primary : null,
                                ),
                              ),
                            ),
                            TextButton.icon(
                              onPressed: _pickCustomRange,
                              icon: const Icon(Icons.date_range, size: 18),
                              label: const Text('Ubah rentang'),
                            ),
                          ],
                        ),
                        if (_startDate != null) _DateStatus(checking: _checkingDates, status: _dateStatus),
                        const SizedBox(height: 110),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  CircleAvatar(
                    backgroundColor: Colors.white.withValues(alpha: 0.85),
                    child: IconButton(
                      tooltip: 'Kembali',
                      icon: const Icon(Icons.arrow_back, color: Colors.black87),
                      onPressed: () => context.canPop() ? context.pop() : context.go('/home'),
                    ),
                  ),
                  CircleAvatar(
                    backgroundColor: Colors.white.withValues(alpha: 0.85),
                    child: IconButton(
                      tooltip: wishlisted ? 'Hapus dari wishlist' : 'Simpan ke wishlist',
                      icon: Icon(wishlisted ? Icons.favorite : Icons.favorite_border,
                          color: wishlisted ? Colors.red : Colors.black87),
                      onPressed: _toggleWishlist,
                    ),
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              color: theme.scaffoldBackgroundColor,
              child: SafeArea(
                top: false,
                child: SizedBox(
                  height: 52,
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: canRequest ? _startRequest : null,
                    child: _isSending
                        ? const SizedBox(
                            height: 22,
                            width: 22,
                            child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                          )
                        : Text(_startDate == null ? 'Pilih tanggal dulu' : 'Ajukan sewa', style: const TextStyle(fontSize: 17)),
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

class _StoreBox extends StatelessWidget {
  const _StoreBox({required this.costume, required this.onContact});
  final Costume costume;
  final VoidCallback onContact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(Icons.storefront, size: 32, color: theme.colorScheme.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(costume.storeName, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                Text(costume.city, style: theme.textTheme.bodySmall),
                if (costume.storeWhatsapp != null)
                  InkWell(
                    onTap: onContact,
                    child: Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text('Tanya via WhatsApp',
                          style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.primary)),
                    ),
                  ),
              ],
            ),
          ),
          TextButton(
            key: const ValueKey('store-profile'),
            onPressed: () => context.push('/store_detail/${costume.storeId}'),
            child: const Text('Lihat toko'),
          ),
        ],
      ),
    );
  }
}

/// Penjelasan jujur tentang arti kalender (lihat README backend).
class _CalendarNote extends StatelessWidget {
  const _CalendarNote({required this.availability});
  final ProductAvailability? availability;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final a = availability;
    final String text;
    if (a == null) {
      text = 'Jadwal toko belum bisa dimuat. Kamu tetap bisa mengirim permintaan.';
    } else if (!a.calendarActive) {
      text = 'Toko ini belum memakai kalender online. Tanggal kosong belum tentu tersedia — '
          'kirim permintaan, toko akan mengonfirmasi.';
    } else {
      final updated = a.calendarUpdatedAt;
      text = 'Tanggal dicoret sudah dipesan (termasuk persiapan & laundry). Tanggal kosong = belum ada jadwal, '
          'tetap dikonfirmasi toko.'
          '${updated == null ? '' : ' Kalender diperbarui ${_ago(updated)}.'}';
    }
    return Text(text, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant));
  }

  static String _ago(DateTime t) {
    final d = DateTime.now().difference(t.toLocal());
    if (d.inMinutes < 60) return '${d.inMinutes < 1 ? 1 : d.inMinutes} menit lalu';
    if (d.inHours < 24) return '${d.inHours} jam lalu';
    return '${d.inDays} hari lalu';
  }
}

class _DateStatus extends StatelessWidget {
  const _DateStatus({required this.checking, required this.status});
  final bool checking;
  final String? status;

  @override
  Widget build(BuildContext context) {
    if (checking) {
      return const Padding(
        padding: EdgeInsets.only(top: 4),
        child: Text('Memeriksa jadwal toko…'),
      );
    }
    final (IconData icon, Color color, String text) = switch (status) {
      'booked' => (Icons.event_busy, Colors.red.shade700, 'Sudah dipesan pada tanggal ini (termasuk waktu persiapan/laundry).'),
      'not_rentable' => (Icons.block, Colors.red.shade700, 'Ukuran ini sedang tidak disewakan.'),
      'no_schedule' => (Icons.event_available, Colors.green.shade700, 'Belum ada jadwal pada tanggal ini. Toko tetap akan mengonfirmasi.'),
      _ => (Icons.info_outline, Colors.grey.shade700, 'Toko akan mengonfirmasi ketersediaan.'),
    };
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 6),
          Expanded(child: Text(text, style: TextStyle(color: color))),
        ],
      ),
    );
  }
}

class _RequestSheet extends StatefulWidget {
  const _RequestSheet({
    required this.costume,
    required this.size,
    required this.start,
    required this.end,
    required this.hasPhone,
    required this.sending,
    required this.onSubmit,
  });
  final Costume costume;
  final String? size;
  final DateTime start;
  final DateTime end;
  final bool hasPhone;
  final bool sending;
  final Future<void> Function(String note, bool contactConsent) onSubmit;

  @override
  State<_RequestSheet> createState() => _RequestSheetState();
}

class _RequestSheetState extends State<_RequestSheet> {
  final _note = TextEditingController();
  bool _consent = true;

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = widget.costume;
    final days = widget.end.difference(widget.start).inDays + 1;
    final rent = c.estimateRent(days);
    final dateText = '${DateFormat('EEE, d MMM', 'id_ID').format(widget.start)} – '
        '${DateFormat('EEE, d MMM yyyy', 'id_ID').format(widget.end)}';

    return Padding(
      padding: EdgeInsets.fromLTRB(20, 16, 20, MediaQuery.of(context).viewInsets.bottom + 20),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Ajukan sewa', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Text(c.name, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
            Text('${c.storeName} · Ukuran ${widget.size ?? '-'}'),
            Text('$dateText ($days hari)'),
            const Divider(height: 24),
            if (c.hasPrice) ...[
              _row('Perkiraan sewa', rupiah(rent)),
              if (days > (c.durationDays ?? days))
                Text('Paket ${c.durationDays} hari + ${days - c.durationDays!} hari tambahan',
                    style: theme.textTheme.bodySmall),
              if (c.depositIdr > 0) _row('Deposit (dikembalikan)', rupiah(c.depositIdr)),
              const SizedBox(height: 4),
              Text('Harga final dikonfirmasi toko. Pembayaran diatur langsung dengan toko.',
                  style: theme.textTheme.bodySmall),
            ] else
              const Text('Toko belum mencantumkan harga; toko akan mengirim penawaran.'),
            const SizedBox(height: 16),
            TextField(
              controller: _note,
              maxLength: 500,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Catatan untuk toko (opsional)',
                hintText: 'Mis. untuk event apa, ambil/kirim, pertanyaan ukuran',
              ),
            ),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              value: _consent,
              onChanged: (v) => setState(() => _consent = v ?? false),
              title: const Text('Izinkan toko melihat nama & nomor HP saya'),
              subtitle: widget.hasPhone ? null : const Text('Nomor HP belum diisi di profil.'),
            ),
            const SizedBox(height: 8),
            Text(
              'Ini permintaan, bukan booking. Tanggal baru terkunci setelah toko mengonfirmasi; '
              'kabarnya muncul di menu Permintaan Sewa dan notifikasi.',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: widget.sending ? null : () => widget.onSubmit(_note.text, _consent),
                child: const Text('Kirim permintaan'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _row(String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [Text(label), Text(value, style: const TextStyle(fontWeight: FontWeight.w600))],
        ),
      );
}
