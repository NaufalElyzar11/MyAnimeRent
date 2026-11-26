import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models/store_admin.dart';
import '../../services/auth_service.dart';
import '../../services/store_admin_service.dart';
import '../../services/supabase_service.dart';
import '../product_detail_screen.dart' show rupiah;
import 'store_calendar_tab.dart';

/// Jadwal satu set fisik per bulan: lihat siapa memakai kapan, catat sewa WA/IG/langsung,
/// blok laundry/perbaikan, lepas blok, atau batalkan sewa.
class UnitScheduleScreen extends StatefulWidget {
  const UnitScheduleScreen({super.key, required this.storeId, required this.unitId, this.initialMonth});
  final String storeId;
  final String unitId;
  final DateTime? initialMonth;

  @override
  State<UnitScheduleScreen> createState() => _UnitScheduleScreenState();
}

class _UnitScheduleScreenState extends State<UnitScheduleScreen> {
  final _service = StoreAdminService();
  late DateTime _month = monthStart(widget.initialMonth ?? DateTime.now());
  StoreCalendar? _data;
  bool _loading = true;
  String? _error;

  CalendarUnit? get _unit {
    for (final u in _data?.units ?? const <CalendarUnit>[]) {
      if (u.unitId == widget.unitId) return u;
    }
    return null;
  }

  List<Allocation> get _allocations => _data?.forUnit(widget.unitId) ?? const [];
  bool get _canBlock => (_data?.calendarEnabled ?? false) && (_data?.canManageCalendar ?? false);
  bool get _canRecord => _canBlock && (_data?.canManageOrders ?? false);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      // Muat seminggu sebelum & sesudah agar sewa yang melewati batas bulan tetap terlihat.
      final from = _month.subtract(const Duration(days: 7));
      final data = await _service.getCalendar(widget.storeId, from: from, days: daysInMonth(_month) + 14);
      if (!mounted) return;
      setState(() {
        _data = data;
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

  void _shift(int months) {
    setState(() => _month = DateTime(_month.year, _month.month + months));
    _load();
  }

  void _snack(String msg, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg), backgroundColor: error ? Colors.red.shade700 : null));
  }

  Future<void> _onDayTap(DateTime day) async {
    for (final a in _allocations) {
      if (a.covers(day)) return _openAllocation(a);
    }
    if (!_canBlock || day.isBefore(today().subtract(const Duration(days: 30)))) return;
    await _add(initialDay: day);
  }

  Future<void> _add({DateTime? initialDay}) async {
    final unit = _unit;
    if (unit == null) return;
    final saved = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _AddScheduleSheet(
        unit: unit,
        initialDay: initialDay,
        canRecord: _canRecord,
        service: _service,
      ),
    );
    if (saved != null) {
      _snack(saved);
      await _load();
    }
  }

  Future<void> _openAllocation(Allocation a) async {
    final changed = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _AllocationSheet(
        allocation: a,
        canRelease: _canBlock,
        canCancel: _data?.canManageOrders ?? false,
        service: _service,
      ),
    );
    if (changed != null) {
      _snack(changed);
      await _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final unit = _unit;
    final inMonth = _allocations
        .where((a) => a.endExclusive.isAfter(_month) && a.start.isBefore(DateTime(_month.year, _month.month + 1)))
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(unit?.productTitle ?? 'Jadwal set', maxLines: 1, overflow: TextOverflow.ellipsis),
            if (unit != null)
              Text([unit.sizeLabel, if (unit.code != null) unit.code!].join(' · '), style: theme.textTheme.bodySmall),
          ],
        ),
      ),
      floatingActionButton: _canBlock && unit != null
          ? FloatingActionButton.extended(
              onPressed: () => _add(),
              icon: const Icon(Icons.add),
              label: const Text('Tambah jadwal'),
            )
          : null,
      body: _loading && _data == null
          ? const Center(child: CircularProgressIndicator())
          : _error != null && _data == null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(_error!, textAlign: TextAlign.center),
                      const SizedBox(height: 8),
                      OutlinedButton(onPressed: _load, child: const Text('Coba lagi')),
                    ],
                  ),
                )
              : unit == null
                  ? const Center(child: Text('Set ini tidak ditemukan atau sudah tidak dipakai.'))
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView(
                        padding: const EdgeInsets.fromLTRB(12, 8, 12, 96),
                        children: [
                          Row(
                            children: [
                              IconButton(onPressed: () => _shift(-1), icon: const Icon(Icons.chevron_left)),
                              Expanded(
                                child: Text(
                                  DateFormat('MMMM yyyy', 'id_ID').format(_month),
                                  textAlign: TextAlign.center,
                                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                                ),
                              ),
                              IconButton(onPressed: () => _shift(1), icon: const Icon(Icons.chevron_right)),
                            ],
                          ),
                          if (_loading) const LinearProgressIndicator(minHeight: 2),
                          _MonthGrid(month: _month, allocations: _allocations, onTap: _onDayTap),
                          const SizedBox(height: 8),
                          const CalendarLegend(),
                          const SizedBox(height: 4),
                          Text(
                            _canBlock
                                ? 'Ketuk tanggal kosong untuk menambah jadwal, atau tanggal berwarna untuk melihat rinciannya.'
                                : 'Ketuk tanggal berwarna untuk melihat rinciannya.',
                            style: theme.textTheme.bodySmall,
                          ),
                          const Divider(height: 24),
                          Text('Jadwal bulan ini', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
                          if (inMonth.isEmpty)
                            const Padding(padding: EdgeInsets.only(top: 8), child: Text('Kosong. Penyewa melihat "belum ada jadwal".')),
                          for (final a in inMonth)
                            ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: CircleAvatar(radius: 8, backgroundColor: allocationColor(a.kind, theme.colorScheme)),
                              title: Text('${rangeLabel(a.start, a.end)} · ${a.kindLabel}'),
                              subtitle: Text(
                                [
                                  if (a.order?.customerName != null) a.order!.customerName!,
                                  if (a.order?.requestCode != null) a.order!.requestCode!,
                                  if (a.note != null) a.note!,
                                ].join(' · '),
                              ),
                              trailing: const Icon(Icons.chevron_right),
                              onTap: () => _openAllocation(a),
                            ),
                        ],
                      ),
                    ),
    );
  }
}

class _MonthGrid extends StatelessWidget {
  const _MonthGrid({required this.month, required this.allocations, required this.onTap});
  final DateTime month;
  final List<Allocation> allocations;
  final void Function(DateTime day) onTap;

  static const _weekdays = ['Sen', 'Sel', 'Rab', 'Kam', 'Jum', 'Sab', 'Min'];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final lead = DateTime(month.year, month.month, 1).weekday - 1; // Senin = 0
    final n = daysInMonth(month);
    final cells = lead + n;
    final rows = (cells / 7).ceil();
    final now = today();

    return Column(
      children: [
        Row(
          children: [
            for (final w in _weekdays)
              Expanded(child: Center(child: Text(w, style: theme.textTheme.labelSmall))),
          ],
        ),
        const SizedBox(height: 4),
        for (var r = 0; r < rows; r++)
          Row(
            children: [
              for (var c = 0; c < 7; c++)
                Expanded(
                  child: Builder(builder: (context) {
                    final dayNum = r * 7 + c - lead + 1;
                    if (dayNum < 1 || dayNum > n) return const SizedBox(height: 44);
                    final day = DateTime(month.year, month.month, dayNum);
                    Allocation? hit;
                    for (final a in allocations) {
                      if (a.covers(day)) {
                        hit = a;
                        break;
                      }
                    }
                    final color = hit == null ? null : allocationColor(hit.kind, scheme);
                    return Padding(
                      padding: const EdgeInsets.all(2),
                      child: Material(
                        color: color ?? scheme.surfaceContainerHighest.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(8),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(8),
                          onTap: () => onTap(day),
                          child: Container(
                            height: 40,
                            alignment: Alignment.center,
                            decoration: day == now
                                ? BoxDecoration(
                                    border: Border.all(color: scheme.onSurface, width: 1.5),
                                    borderRadius: BorderRadius.circular(8),
                                  )
                                : null,
                            child: Text(
                              '$dayNum',
                              style: TextStyle(
                                color: color == null
                                    ? (day.isBefore(now) ? scheme.onSurfaceVariant : scheme.onSurface)
                                    : Colors.white,
                                fontWeight: color == null ? FontWeight.normal : FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  }),
                ),
            ],
          ),
      ],
    );
  }
}

/// Rincian satu jadwal + tindakan yang diizinkan. Mengembalikan pesan sukses bila ada perubahan.
class _AllocationSheet extends StatefulWidget {
  const _AllocationSheet({
    required this.allocation,
    required this.canRelease,
    required this.canCancel,
    required this.service,
  });

  final Allocation allocation;
  final bool canRelease;
  final bool canCancel;
  final StoreAdminService service;

  @override
  State<_AllocationSheet> createState() => _AllocationSheetState();
}

class _AllocationSheetState extends State<_AllocationSheet> {
  bool _busy = false;
  String? _error;

  Future<void> _run(Future<void> Function() action, String success) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
      if (mounted) Navigator.pop(context, success);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = e.reason == 'STALE_REVISION' ? 'Data sudah berubah. Tutup lalu buka lagi.' : e.message;
      });
    }
  }

  Future<void> _cancelOrder(AllocationOrder o) async {
    final reason = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Batalkan sewa ini?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(o.source == 'platform'
                ? 'Tanggal kosong lagi dan penyewa diberi tahu lewat app.'
                : 'Tanggal kosong lagi. Kabari pelanggan Anda secara langsung.'),
            TextField(controller: reason, maxLength: 200, decoration: const InputDecoration(labelText: 'Alasan')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Tidak')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Batalkan sewa')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    await _run(() => widget.service.cancelOrder(orderId: o.id, version: o.version, reason: reason.text), 'Sewa dibatalkan.');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final a = widget.allocation;
    final o = a.order;
    final fmt = DateFormat('EEE, d MMM yyyy', 'id_ID');
    final phone = o?.customerPhone;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(radius: 8, backgroundColor: allocationColor(a.kind, theme.colorScheme)),
                const SizedBox(width: 8),
                Text(a.kindLabel, style: theme.textTheme.titleLarge),
              ],
            ),
            const SizedBox(height: 8),
            if (o != null) ...[
              Text('Disewa ${fmt.format(o.rentStart)} – ${fmt.format(o.rentEnd)}'),
              if (a.start != o.rentStart || a.endExclusive != o.rentEndExclusive)
                Text('Set terkunci ${rangeLabel(a.start, a.end)} (termasuk persiapan/laundry)',
                    style: theme.textTheme.bodySmall),
              if (o.requestCode != null) Text('Kode permintaan: ${o.requestCode}'),
              if (o.customerName != null) Text('Pelanggan: ${o.customerName}'),
              if (phone != null)
                Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(phone),
                    TextButton.icon(
                      onPressed: () => launchUrl(Uri.parse('https://wa.me/${phone.replaceAll(RegExp(r'[^0-9]'), '')}'),
                          mode: LaunchMode.externalApplication),
                      icon: const Icon(Icons.chat_outlined, size: 18),
                      label: const Text('WhatsApp'),
                    ),
                  ],
                ),
              if (o.customerNote != null) Text('Catatan: ${o.customerNote}'),
              if (o.totalRentIdr != null)
                Text('Biaya sewa ${rupiah(o.totalRentIdr!)}'
                    '${(o.depositIdr ?? 0) > 0 ? ' · Deposit ${rupiah(o.depositIdr!)}' : ''}'),
            ] else ...[
              Text(rangeLabel(a.start, a.end)),
              if (a.note != null) Text('Catatan: ${a.note}'),
            ],
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(_error!, style: TextStyle(color: theme.colorScheme.error)),
            ],
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (o?.requestId != null)
                  OutlinedButton.icon(
                    onPressed: _busy
                        ? null
                        : () {
                            final router = GoRouter.of(context);
                            Navigator.pop(context);
                            router.push('/store/requests/${o!.requestId}');
                          },
                    icon: const Icon(Icons.forum_outlined),
                    label: const Text('Buka permintaan'),
                  ),
                if (a.isBlock && widget.canRelease)
                  FilledButton.tonalIcon(
                    onPressed: _busy ? null : () => _run(() => widget.service.releaseBlock(a.id), 'Blok dihapus.'),
                    icon: const Icon(Icons.delete_outline),
                    label: const Text('Hapus blok'),
                  ),
                if (o != null && o.canCancel && widget.canCancel)
                  FilledButton.tonalIcon(
                    onPressed: _busy ? null : () => _cancelOrder(o),
                    icon: const Icon(Icons.event_busy_outlined),
                    label: const Text('Batalkan sewa'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Form "Tambah jadwal": sewa dari WA/IG/datang langsung, atau blok laundry/perbaikan.
class _AddScheduleSheet extends StatefulWidget {
  const _AddScheduleSheet({required this.unit, required this.canRecord, required this.service, this.initialDay});
  final CalendarUnit unit;
  final DateTime? initialDay;
  final bool canRecord;
  final StoreAdminService service;

  @override
  State<_AddScheduleSheet> createState() => _AddScheduleSheetState();
}

class _AddScheduleSheetState extends State<_AddScheduleSheet> {
  late bool _rental = widget.canRecord;
  String _source = 'whatsapp';
  String _blockKind = 'laundry';
  late DateTime _first = widget.initialDay ?? today();
  late DateTime _last = _first;
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _note = TextEditingController();
  String? _operationId; // dipakai ulang saat mencoba lagi setelah gangguan jaringan
  bool _busy = false;
  String? _error;

  static const _sources = {
    'whatsapp': 'WhatsApp',
    'instagram': 'Instagram',
    'walk_in': 'Datang langsung',
    'other': 'Lainnya',
  };

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _note.dispose();
    super.dispose();
  }

  void _changed() => _operationId = null; // isian berubah → aksi baru

  Future<void> _pickRange() async {
    final now = today();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: now.subtract(const Duration(days: 30)),
      lastDate: now.add(const Duration(days: 365)),
      initialDateRange: DateTimeRange(start: _first, end: _last),
      helpText: _rental ? 'Tanggal sewa' : 'Tanggal blok',
      saveText: 'Pilih',
    );
    if (picked == null || !mounted) return;
    setState(() {
      _first = DateTime(picked.start.year, picked.start.month, picked.start.day);
      _last = DateTime(picked.end.year, picked.end.month, picked.end.day);
      _changed();
    });
  }

  Future<void> _save() async {
    String? phone;
    if (_rental && _phone.text.trim().isNotEmpty) {
      phone = AuthService.normalizePhone(_phone.text);
      if (phone == null) {
        setState(() => _error = 'Nomor HP tidak valid. Contoh: 081234567890');
        return;
      }
    }
    _operationId ??= newOperationId();
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      if (_rental) {
        await widget.service.recordOfflineOrder(
          operationId: _operationId!,
          unitId: widget.unit.unitId,
          firstDay: _first,
          lastDay: _last,
          source: _source,
          customerName: _name.text,
          customerPhone: phone,
          note: _note.text,
        );
      } else {
        await widget.service.blockUnit(
          operationId: _operationId!,
          unitId: widget.unit.unitId,
          firstDay: _first,
          lastDay: _last,
          kind: _blockKind,
          note: _note.text,
        );
      }
      if (mounted) {
        Navigator.pop(context, _rental ? 'Sewa dicatat. Tanggal ini tampil "sudah dipesan" untuk penyewa.' : 'Blok disimpan.');
      }
    } on ApiException catch (e) {
      if (!e.isNetwork) _operationId = null;
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = switch (e.code) {
          'UNIT_UNAVAILABLE' => 'Bentrok dengan jadwal lain pada set ini (termasuk hari laundry). Pilih tanggal lain.',
          'FEATURE_NOT_AVAILABLE' => 'Kalender belum termasuk paket toko ini.',
          'FORBIDDEN' => 'Akun Anda tidak punya izin untuk tindakan ini.',
          _ => e.message,
        };
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final days = _last.difference(_first).inDays + 1;
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 0, 16, 16 + MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Tambah jadwal', style: theme.textTheme.titleLarge),
            Text('${widget.unit.productTitle} · ${widget.unit.sizeLabel}', style: theme.textTheme.bodySmall),
            const SizedBox(height: 12),
            if (widget.canRecord)
              SegmentedButton<bool>(
                segments: const [
                  ButtonSegment(value: true, label: Text('Sewa WA/IG/langsung'), icon: Icon(Icons.person_outline)),
                  ButtonSegment(value: false, label: Text('Laundry/perbaikan'), icon: Icon(Icons.local_laundry_service_outlined)),
                ],
                selected: {_rental},
                onSelectionChanged: (s) => setState(() {
                  _rental = s.first;
                  _changed();
                }),
              ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _busy ? null : _pickRange,
              icon: const Icon(Icons.date_range),
              label: Text('${rangeLabel(_first, _last)} ($days hari)'),
            ),
            const SizedBox(height: 12),
            if (_rental) ...[
              DropdownButtonFormField<String>(
                initialValue: _source,
                decoration: const InputDecoration(labelText: 'Sumber pesanan'),
                items: [for (final e in _sources.entries) DropdownMenuItem(value: e.key, child: Text(e.value))],
                onChanged: (v) => setState(() {
                  _source = v ?? _source;
                  _changed();
                }),
              ),
              TextField(
                controller: _name,
                maxLength: 80,
                decoration: const InputDecoration(labelText: 'Nama pelanggan (opsional)'),
                onChanged: (_) => _changed(),
              ),
              TextField(
                controller: _phone,
                keyboardType: TextInputType.phone,
                maxLength: 16,
                decoration: const InputDecoration(labelText: 'No. HP pelanggan (opsional)'),
                onChanged: (_) => _changed(),
              ),
              Text(
                'Hari persiapan/laundry setelah sewa ditambahkan otomatis sesuai pengaturan kostum. '
                'Data pelanggan hanya terlihat oleh owner dan staf order.',
                style: theme.textTheme.bodySmall,
              ),
            ] else
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'laundry', label: Text('Laundry')),
                  ButtonSegment(value: 'maintenance', label: Text('Perbaikan')),
                ],
                selected: {_blockKind},
                onSelectionChanged: (s) => setState(() {
                  _blockKind = s.first;
                  _changed();
                }),
              ),
            TextField(
              controller: _note,
              maxLength: 200,
              decoration: const InputDecoration(labelText: 'Catatan (opsional)'),
              onChanged: (_) => _changed(),
            ),
            if (_error != null) ...[
              Text(_error!, style: TextStyle(color: theme.colorScheme.error)),
              const SizedBox(height: 8),
            ],
            FilledButton(
              onPressed: _busy ? null : _save,
              child: _busy
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Simpan'),
            ),
          ],
        ),
      ),
    );
  }
}
