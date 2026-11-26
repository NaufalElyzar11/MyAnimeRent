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
import '../config/theme.dart';
import '../widgets/expandable_calendar_view.dart';
import '../widgets/ui_kit.dart';

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

  final _calendarKey = GlobalKey();

  /// Tombol bawah ditekan sebelum memilih tanggal: gulir ke kalender.
  void _goToCalendar() {
    final ctx = _calendarKey.currentContext;
    if (ctx != null) {
      Scrollable.ensureVisible(ctx, duration: const Duration(milliseconds: 400), curve: Curves.easeOut, alignment: 0.1);
    }
    _snack('Ketuk tanggal mulai di kalender.');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(),
        body: const _DetailSkeleton(),
      );
    }
    final costume = _costume;
    if (costume == null) {
      return Scaffold(
        appBar: AppBar(),
        body: Center(
          child: EmptyState(
            icon: _error != null ? Icons.wifi_off_rounded : Icons.search_off_rounded,
            title: _error != null ? 'Kostum belum bisa dimuat' : 'Kostum tidak tersedia',
            message: _error != null
                ? 'Periksa koneksi lalu coba lagi.'
                : 'Kostum ini sudah ditarik toko atau tautannya tidak berlaku lagi.',
            actionLabel: _error != null ? 'Coba lagi' : 'Cari kostum lain',
            onAction: _error != null ? _load : () => context.go('/search'),
          ),
        ),
      );
    }

    final wishlisted = context.watch<WishlistProvider>().isItemInWishlist(costume.id);
    final availability = _availability;
    final variantAv = _variantAvailability;
    final rangeDays = costume.durationDays ?? 3;
    final blocked = _dateStatus == 'booked' || !(variantAv?.rentable ?? true);
    final media = MediaQuery.sizeOf(context);
    final galleryHeight = media.width.clamp(240.0, media.height * 0.55 < 240 ? 240.0 : media.height * 0.55);
    final muted = theme.colorScheme.onSurfaceVariant;
    final tags = [costume.character, costume.anime].where((s) => s.isNotEmpty && s != 'Lainnya').toSet().toList();

    return Scaffold(
      bottomNavigationBar: _BookingBar(
        costume: costume,
        days: _days,
        sending: _isSending,
        blocked: blocked,
        hasDates: _startDate != null,
        onPressed: _startDate == null ? _goToCalendar : _startRequest,
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        edgeOffset: galleryHeight,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverAppBar(
              pinned: true,
              stretch: true,
              expandedHeight: galleryHeight,
              backgroundColor: theme.scaffoldBackgroundColor,
              leading: Padding(
                padding: const EdgeInsets.all(6),
                child: _CircleButton(
                  icon: Icons.arrow_back,
                  tooltip: 'Kembali',
                  onPressed: () => context.canPop() ? context.pop() : context.go('/home'),
                ),
              ),
              actions: [
                Padding(
                  padding: const EdgeInsets.all(6),
                  child: _CircleButton(
                    icon: wishlisted ? Icons.favorite : Icons.favorite_border,
                    color: wishlisted ? AppColors.pink : null,
                    tooltip: wishlisted ? 'Hapus dari favorit' : 'Simpan ke favorit',
                    onPressed: _toggleWishlist,
                  ),
                ),
              ],
              flexibleSpace: FlexibleSpaceBar(
                background: _Gallery(images: costume.imageUrls, title: costume.name),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(AppSpacing.page, 16, AppSpacing.page, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (tags.isNotEmpty)
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [for (final t in tags) _Tag(text: t)],
                      ),
                    const SizedBox(height: 8),
                    Text(costume.name, style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 10),
                    _PriceBlock(costume: costume),
                    const SizedBox(height: 16),
                    _StoreBox(costume: costume, onContact: () => _contactStore(costume)),
                    const SizedBox(height: AppSpacing.section),
                    const SectionHeader(title: 'Pilih ukuran'),
                    if (costume.variants.isEmpty)
                      Text('Ukuran belum diinformasikan. Tanyakan lewat catatan saat mengajukan.',
                          style: theme.textTheme.bodyMedium?.copyWith(color: muted))
                    else
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final v in costume.variants)
                            ChoiceChip(
                              label: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                child: Text(v.size),
                              ),
                              showCheckmark: false,
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
                      const SizedBox(height: 10),
                      InfoBanner(icon: Icons.straighten, text: costume.sizeNotes!),
                    ],
                    if (variantAv != null && !variantAv.rentable)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text('Ukuran ini sedang tidak disewakan.',
                            style: TextStyle(color: theme.colorScheme.error, fontWeight: FontWeight.w600)),
                      ),
                    const SizedBox(height: AppSpacing.section),
                    SectionHeader(
                      key: _calendarKey,
                      title: 'Pilih tanggal sewa',
                      subtitle: 'Ketuk tanggal mulai, otomatis $rangeDays hari',
                    ),
                    Card(
                      margin: EdgeInsets.zero,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(8, 4, 8, 12),
                        child: ExpandableCalendarView(
                          bookedDates: variantAv?.bookedDateKeys ?? const [],
                          selectedStartDate: _startDate,
                          selectedEndDate: _endDate,
                          rangeDays: rangeDays,
                          onDateRangeSelected: _setRange,
                          onSelectionInvalid: (msg) => _snack(msg, error: true),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    _SelectionSummary(
                      start: _startDate,
                      end: _endDate,
                      days: _days,
                      onCustom: _pickCustomRange,
                      onClear: _startDate == null ? null : () => setState(_resetDates),
                    ),
                    if (_startDate != null) _DateStatus(checking: _checkingDates, status: _dateStatus),
                    const SizedBox(height: 10),
                    _CalendarNote(availability: availability),
                    if (costume.packageContents.isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.section),
                      const SectionHeader(title: 'Isi paket'),
                      for (final item in costume.packageContents)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(Icons.check_circle_rounded, size: 18, color: AppColors.success),
                              const SizedBox(width: 8),
                              Expanded(child: Text(item)),
                            ],
                          ),
                        ),
                    ],
                    if (costume.description.isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.section),
                      const SectionHeader(title: 'Deskripsi'),
                      _ExpandableText(text: costume.description),
                    ],
                    const SizedBox(height: AppSpacing.section),
                    const InfoBanner(
                      icon: Icons.verified_user_outlined,
                      text: 'Mengajukan sewa belum berarti membayar. Toko mengonfirmasi dulu, '
                          'lalu pembayaran & pengambilan diatur bersama toko.',
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CircleButton extends StatelessWidget {
  const _CircleButton({required this.icon, required this.tooltip, required this.onPressed, this.color});
  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;
  final Color? color;

  @override
  Widget build(BuildContext context) => Material(
        color: Colors.white.withValues(alpha: 0.92),
        shape: const CircleBorder(),
        elevation: 1,
        child: IconButton(
          tooltip: tooltip,
          onPressed: onPressed,
          icon: Icon(icon, color: color ?? Colors.black87, size: 22),
        ),
      );
}

/// Foto kostum: geser antar foto, ketuk untuk memperbesar.
class _Gallery extends StatefulWidget {
  const _Gallery({required this.images, required this.title});
  final List<String> images;
  final String title;

  @override
  State<_Gallery> createState() => _GalleryState();
}

class _GalleryState extends State<_Gallery> {
  int _page = 0;

  void _openFull(int index) {
    showDialog<void>(
      context: context,
      barrierColor: Colors.black,
      builder: (ctx) => Stack(
        children: [
          PageView.builder(
            controller: PageController(initialPage: index),
            itemCount: widget.images.length,
            itemBuilder: (_, i) => InteractiveViewer(
              maxScale: 4,
              child: Center(child: CachedNetworkImage(imageUrl: widget.images[i], fit: BoxFit.contain)),
            ),
          ),
          SafeArea(
            child: Align(
              alignment: Alignment.topRight,
              child: IconButton(
                tooltip: 'Tutup',
                icon: const Icon(Icons.close, color: Colors.white),
                onPressed: () => Navigator.pop(ctx),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (widget.images.isEmpty) {
      return Container(
        color: theme.colorScheme.surfaceContainerHighest,
        child: Icon(Icons.checkroom_outlined, size: 72, color: theme.colorScheme.onSurfaceVariant),
      );
    }
    return Stack(
      fit: StackFit.expand,
      children: [
        PageView.builder(
          itemCount: widget.images.length,
          onPageChanged: (i) => setState(() => _page = i),
          itemBuilder: (_, i) => GestureDetector(
            onTap: () => _openFull(i),
            child: CachedNetworkImage(
              imageUrl: widget.images[i],
              fit: BoxFit.cover,
              width: double.infinity,
              placeholder: (_, _) => Container(color: theme.colorScheme.surfaceContainerHighest),
              errorWidget: (_, _, _) => Container(
                color: theme.colorScheme.surfaceContainerHighest,
                child: const Icon(Icons.image_not_supported_outlined, size: 60),
              ),
            ),
          ),
        ),
        if (widget.images.length > 1)
          Positioned(
            left: 0,
            right: 0,
            bottom: 14,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var i = 0; i < widget.images.length; i++)
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    width: i == _page ? 18 : 7,
                    height: 7,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: i == _page ? 1 : 0.6),
                      borderRadius: BorderRadius.circular(4),
                      boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4)],
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.purple.withValues(alpha: theme.brightness == Brightness.dark ? 0.3 : 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(text,
          style: theme.textTheme.labelMedium?.copyWith(
            color: theme.brightness == Brightness.dark ? const Color(0xFFC9B3FF) : AppColors.purple,
            fontWeight: FontWeight.w600,
          )),
    );
  }
}

class _PriceBlock extends StatelessWidget {
  const _PriceBlock({required this.costume});
  final Costume costume;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    if (!costume.hasPrice) {
      return Text('Harga belum dicantumkan — toko akan memberi penawaran.',
          style: theme.textTheme.bodyMedium?.copyWith(color: muted));
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text.rich(TextSpan(children: [
          TextSpan(
            text: rupiah(costume.price),
            style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700, color: theme.colorScheme.primary),
          ),
          TextSpan(text: '  / ${costume.durationDays} hari', style: theme.textTheme.bodyMedium?.copyWith(color: muted)),
        ])),
        const SizedBox(height: 6),
        Wrap(
          spacing: 14,
          runSpacing: 4,
          children: [
            if ((costume.extraDayIdr ?? 0) > 0)
              _Fact(icon: Icons.add_circle_outline, text: 'Tambah hari ${rupiah(costume.extraDayIdr!)}/hari'),
            _Fact(
              icon: Icons.shield_outlined,
              text: costume.depositIdr > 0 ? 'Deposit ${rupiah(costume.depositIdr)} (kembali)' : 'Tanpa deposit',
            ),
          ],
        ),
      ],
    );
  }
}

class _Fact extends StatelessWidget {
  const _Fact({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: theme.colorScheme.onSurfaceVariant),
        const SizedBox(width: 4),
        Text(text, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
      ],
    );
  }
}

class _SelectionSummary extends StatelessWidget {
  const _SelectionSummary({
    required this.start,
    required this.end,
    required this.days,
    required this.onCustom,
    required this.onClear,
  });
  final DateTime? start;
  final DateTime? end;
  final int days;
  final VoidCallback onCustom;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final picked = start != null && end != null;
    return Row(
      children: [
        Icon(Icons.event_note_outlined, size: 20, color: picked ? theme.colorScheme.primary : theme.colorScheme.onSurfaceVariant),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            picked
                ? '${DateFormat('EEE, d MMM', 'id_ID').format(start!)} – '
                    '${DateFormat('EEE, d MMM', 'id_ID').format(end!)} · $days hari'
                : 'Belum memilih tanggal',
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: picked ? FontWeight.w600 : FontWeight.normal,
              color: picked ? null : theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        if (onClear != null) IconButton(tooltip: 'Hapus pilihan', onPressed: onClear, icon: const Icon(Icons.close, size: 20)),
        TextButton(onPressed: onCustom, child: Text(picked ? 'Ubah' : 'Rentang lain')),
      ],
    );
  }
}

class _ExpandableText extends StatefulWidget {
  const _ExpandableText({required this.text});
  final String text;

  @override
  State<_ExpandableText> createState() => _ExpandableTextState();
}

class _ExpandableTextState extends State<_ExpandableText> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final long = widget.text.length > 220 || '\n'.allMatches(widget.text).length > 3;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.text,
          maxLines: _open || !long ? null : 4,
          overflow: _open || !long ? null : TextOverflow.ellipsis,
          style: theme.textTheme.bodyMedium?.copyWith(height: 1.5),
        ),
        if (long)
          TextButton(
            style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(48, 36)),
            onPressed: () => setState(() => _open = !_open),
            child: Text(_open ? 'Lebih sedikit' : 'Selengkapnya'),
          ),
      ],
    );
  }
}

/// Bar bawah: harga/perkiraan + tombol utama yang selalu terlihat.
class _BookingBar extends StatelessWidget {
  const _BookingBar({
    required this.costume,
    required this.days,
    required this.sending,
    required this.blocked,
    required this.hasDates,
    required this.onPressed,
  });
  final Costume costume;
  final int days;
  final bool sending;
  final bool blocked;
  final bool hasDates;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    final String label;
    final String value;
    if (!costume.hasPrice) {
      label = 'Harga';
      value = 'Tanya toko';
    } else if (hasDates && days > 0) {
      label = 'Perkiraan · $days hari';
      value = rupiah(costume.estimateRent(days));
    } else {
      label = 'Mulai dari';
      value = '${rupiah(costume.price)} / ${costume.durationDays} hari';
    }
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(top: BorderSide(color: theme.colorScheme.outlineVariant)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(AppSpacing.page, 10, AppSpacing.page, 10),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label, style: theme.textTheme.labelSmall?.copyWith(color: muted)),
                    Text(value,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              FilledButton(
                onPressed: sending || (hasDates && blocked) ? null : onPressed,
                style: FilledButton.styleFrom(minimumSize: const Size(150, 50)),
                child: sending
                    ? const SizedBox(height: 22, width: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                    : Text(!hasDates ? 'Pilih tanggal' : (blocked ? 'Tidak tersedia' : 'Ajukan sewa')),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DetailSkeleton extends StatelessWidget {
  const _DetailSkeleton();

  @override
  Widget build(BuildContext context) => ListView(
        padding: const EdgeInsets.all(AppSpacing.page),
        children: const [
          SkeletonBox(height: 300, radius: 20),
          SizedBox(height: 16),
          SkeletonBox(width: 120, height: 20, radius: 10),
          SizedBox(height: 10),
          SkeletonBox(width: 260, height: 26, radius: 8),
          SizedBox(height: 10),
          SkeletonBox(width: 180, height: 22, radius: 8),
          SizedBox(height: 20),
          SkeletonBox(height: 72, radius: 16),
        ],
      );
}

class _StoreBox extends StatelessWidget {
  const _StoreBox({required this.costume, required this.onContact});
  final Costume costume;
  final VoidCallback onContact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        key: const ValueKey('store-profile'),
        onTap: () => context.push('/store_detail/${costume.storeId}'),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              StoreAvatar(name: costume.storeName, size: 44),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(costume.storeName, maxLines: 1, overflow: TextOverflow.ellipsis, style: theme.textTheme.titleSmall),
                    Row(
                      children: [
                        Icon(Icons.place_outlined, size: 14, color: theme.colorScheme.onSurfaceVariant),
                        const SizedBox(width: 2),
                        Flexible(
                          child: Text(costume.city,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if (costume.storeWhatsapp != null)
                IconButton.filledTonal(
                  tooltip: 'Tanya via WhatsApp',
                  onPressed: onContact,
                  icon: const Icon(Icons.chat_outlined, size: 20),
                ),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
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
    return InfoBanner(
      icon: a != null && a.calendarActive ? Icons.info_outline : Icons.help_outline,
      text: text,
      color: a != null && a.calendarActive ? theme.colorScheme.secondary : AppColors.warning,
    );
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
    final muted = theme.colorScheme.onSurfaceVariant;
    final dateText = '${DateFormat('EEE, d MMM', 'id_ID').format(widget.start)} – '
        '${DateFormat('EEE, d MMM yyyy', 'id_ID').format(widget.end)}';

    return Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, MediaQuery.of(context).viewInsets.bottom + 20),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Ajukan sewa', style: theme.textTheme.titleLarge),
            const SizedBox(height: 12),
            Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: SizedBox(
                    width: 64,
                    height: 64,
                    child: c.imageUrls.isEmpty
                        ? Container(color: theme.colorScheme.surfaceContainerHighest, child: const Icon(Icons.checkroom))
                        : CachedNetworkImage(imageUrl: c.imageUrls.first, fit: BoxFit.cover),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(c.name, maxLines: 2, overflow: TextOverflow.ellipsis, style: theme.textTheme.titleSmall),
                      Text('${c.storeName} · Ukuran ${widget.size ?? '-'}',
                          style: theme.textTheme.bodySmall?.copyWith(color: muted)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(AppSpacing.radiusSmall),
              ),
              child: Column(
                children: [
                  _row('Tanggal', '$dateText ($days hari)'),
                  if (c.hasPrice) ...[
                    _row('Perkiraan sewa', rupiah(rent)),
                    if (days > (c.durationDays ?? days))
                      Align(
                        alignment: Alignment.centerRight,
                        child: Text('Paket ${c.durationDays} hari + ${days - c.durationDays!} hari tambahan',
                            style: theme.textTheme.labelSmall?.copyWith(color: muted)),
                      ),
                    if (c.depositIdr > 0) _row('Deposit (kembali)', rupiah(c.depositIdr)),
                  ] else
                    _row('Harga', 'Toko akan memberi penawaran'),
                ],
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _note,
              maxLength: 500,
              maxLines: 3,
              minLines: 2,
              decoration: const InputDecoration(
                labelText: 'Catatan untuk toko (opsional)',
                hintText: 'Mis. untuk event apa, ambil/kirim, pertanyaan ukuran',
              ),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _consent,
              onChanged: (v) => setState(() => _consent = v),
              title: const Text('Bagikan nama & nomor HP ke toko'),
              subtitle: Text(widget.hasPhone
                  ? 'Memudahkan toko menghubungimu setelah dikonfirmasi.'
                  : 'Nomor HP belum diisi di Profil.'),
            ),
            const SizedBox(height: 4),
            const InfoBanner(
              icon: Icons.info_outline,
              text: 'Ini permintaan, bukan pembayaran. Tanggal baru terkunci setelah toko mengonfirmasi; '
                  'kabarnya muncul di Permintaan Sewa dan notifikasi.',
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
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
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label),
            const SizedBox(width: 12),
            Expanded(
              child: Text(value, textAlign: TextAlign.right, style: const TextStyle(fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      );
}
