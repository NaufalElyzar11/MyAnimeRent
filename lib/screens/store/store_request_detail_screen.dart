import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models/app_notification.dart';
import '../../models/rental_request.dart';
import '../../models/store_admin.dart';
import '../../providers/notification_provider.dart';
import '../../providers/store_admin_provider.dart';
import '../../services/database_service.dart';
import '../../services/store_admin_service.dart';
import '../../services/supabase_service.dart';
import '../product_detail_screen.dart' show rupiah;
import '../rental_history_screen.dart' show StatusChip;
import '../../widgets/sakuga.dart';

const declineReasons = {
  'dates_unavailable': 'Tanggal sudah terisi',
  'size_unavailable': 'Ukuran tidak tersedia',
  'not_rentable': 'Kostum sedang tidak disewakan',
  'other': 'Alasan lain',
};

/// Detail permintaan dari sisi toko: data penyewa, percakapan, konfirmasi ke set tertentu, atau tolak.
class StoreRequestDetailScreen extends StatefulWidget {
  const StoreRequestDetailScreen({super.key, required this.requestId});
  final String requestId;

  @override
  State<StoreRequestDetailScreen> createState() => _StoreRequestDetailScreenState();
}

class _StoreRequestDetailScreenState extends State<StoreRequestDetailScreen> {
  final _service = StoreAdminService();
  final _db = DatabaseService();
  final _input = TextEditingController();
  final _scroll = ScrollController();
  StoreRequest? _request;
  List<RequestMessage> _messages = [];
  bool _loading = true;
  bool _busy = false;
  String? _error;
  String? _pendingMessageOp;
  String? _pendingConfirmOp;
  NotificationProvider? _notifications;
  int _lastSeen = 0;
  final _actionsKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _load();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final n = context.read<NotificationProvider>();
      _notifications = n;
      _lastSeen = n.items.where((x) => x.requestId == widget.requestId).length;
      n.addListener(_onNotification);
    });
  }

  void _onNotification() {
    final items = _notifications?.items ?? const <AppNotification>[];
    final relevant = items.where((n) => n.requestId == widget.requestId).length;
    if (relevant != _lastSeen) {
      _lastSeen = relevant;
      _load(quiet: true);
    }
  }

  @override
  void dispose() {
    _notifications?.removeListener(_onNotification);
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _load({bool quiet = false}) async {
    if (!quiet) setState(() => _loading = true);
    try {
      final results = await Future.wait([
        _service.getRequest(widget.requestId),
        _db.getMessages(widget.requestId),
      ]);
      if (!mounted) return;
      setState(() {
        _request = results[0] as StoreRequest;
        _messages = results[1] as List<RequestMessage>;
        _error = null;
        _loading = false;
      });
      _markRead();
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.code == 'NOT_FOUND' ? 'Permintaan tidak ditemukan atau Anda tidak punya akses.' : e.message;
        _loading = false;
      });
    }
  }

  void _markRead() {
    final n = _notifications;
    if (n == null) return;
    for (final item in n.items.where((x) => x.requestId == widget.requestId && !x.isRead)) {
      n.markRead(item);
    }
  }

  void _snack(String msg, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg), backgroundColor: error ? Colors.red.shade700 : null));
  }

  /// Setelah gagal karena data basi/bentrok: muat ulang dan beri tahu.
  Future<void> _handleError(ApiException e) async {
    final msg = switch (e.reason) {
      'STALE_REVISION' => 'Permintaan baru saja berubah (mungkin dibatalkan penyewa). Data dimuat ulang.',
      'REQUEST_NOT_OPEN' => 'Permintaan ini sudah tidak terbuka.',
      _ => e.message,
    };
    _snack(msg, error: true);
    await _load(quiet: true);
  }

  Future<void> _send() async {
    final text = _input.text.trim();
    if (text.isEmpty || _busy) return;
    _pendingMessageOp ??= newOperationId();
    setState(() => _busy = true);
    try {
      await _db.postMessage(widget.requestId, text, operationId: _pendingMessageOp!);
      _pendingMessageOp = null;
      _input.clear();
      await _load(quiet: true);
      if (_scroll.hasClients) {
        _scroll.animateTo(_scroll.position.maxScrollExtent,
            duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
      }
    } on ApiException catch (e) {
      if (!e.isNetwork) _pendingMessageOp = null;
      _snack(e.message, error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _confirm(StoreRequest r) async {
    final free = r.freeUnits;
    if (free.isEmpty) {
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Tidak ada set kosong'),
          content: Text(r.units.isEmpty
              ? 'Belum ada set fisik untuk ukuran ini. Tambahkan ukuran di katalog terlebih dahulu.'
              : 'Semua set ukuran ini sudah terpakai pada tanggal tersebut (termasuk hari laundry). '
                  'Tawarkan tanggal lain lewat pesan, atau tolak dengan alasan "Tanggal sudah terisi".'),
          actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Mengerti'))],
        ),
      );
      return;
    }
    final unitId = await showDialog<String>(
      context: context,
      builder: (ctx) => _ConfirmDialog(request: r, freeUnits: free),
    );
    if (unitId == null || !mounted) return;
    _pendingConfirmOp ??= newOperationId();
    setState(() => _busy = true);
    try {
      await _service.confirmRequest(r, unitId: unitId, operationId: _pendingConfirmOp!);
      _pendingConfirmOp = null;
      if (mounted) {
        Sakuga.burst(context, anchor: _actionsKey, word: 'ドン!');
        Sakuga.toast(context, 'Sewa dikonfirmasi. Tanggal sudah dikunci dan penyewa diberi tahu.');
      }
      await _load(quiet: true);
      if (mounted) context.read<StoreAdminProvider>().loadRequests();
    } on ApiException catch (e) {
      if (!e.isNetwork) _pendingConfirmOp = null;
      if (e.code == 'UNIT_UNAVAILABLE') {
        _snack('Set itu baru saja terpakai pada tanggal tersebut. Pilih set lain atau tawarkan tanggal lain.', error: true);
        await _load(quiet: true);
      } else if (e.code == 'FEATURE_NOT_AVAILABLE') {
        _snack('Konfirmasi otomatis butuh fitur kalender, yang belum termasuk paket toko ini.', error: true);
      } else {
        await _handleError(e);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _decline(StoreRequest r) async {
    final result = await showModalBottomSheet<({String reason, String message})>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => const _DeclineSheet(),
    );
    if (result == null || !mounted) return;
    setState(() => _busy = true);
    try {
      await _service.declineRequest(r, reason: result.reason, message: result.message, operationId: newOperationId());
      _snack('Permintaan ditolak. Penyewa sudah diberi tahu.');
      await _load(quiet: true);
      if (mounted) context.read<StoreAdminProvider>().loadRequests();
    } on ApiException catch (e) {
      await _handleError(e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _cancelOrder(StoreRequest r) async {
    final reason = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Batalkan sewa ini?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Tanggal di kalender akan kosong lagi dan penyewa diberi tahu.'),
            TextField(
              controller: reason,
              maxLength: 200,
              decoration: const InputDecoration(labelText: 'Alasan untuk penyewa'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Tidak')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Batalkan sewa')),
        ],
      ),
    );
    if (ok != true || !mounted || r.orderId == null) return;
    setState(() => _busy = true);
    try {
      await _service.cancelOrder(orderId: r.orderId!, version: r.orderVersion ?? 1, reason: reason.text);
      _snack('Sewa dibatalkan.');
      await _load(quiet: true);
      if (mounted) context.read<StoreAdminProvider>().loadRequests();
    } on ApiException catch (e) {
      await _handleError(e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final r = _request;
    return Scaffold(
      appBar: AppBar(title: Text(r?.code ?? 'Permintaan')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : r == null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(_error ?? 'Permintaan tidak ditemukan.', textAlign: TextAlign.center),
                        const SizedBox(height: 12),
                        OutlinedButton(onPressed: _load, child: const Text('Coba lagi')),
                      ],
                    ),
                  ),
                )
              : Column(
                  children: [
                    if (_busy) const LinearProgressIndicator(minHeight: 2),
                    Expanded(
                      child: RefreshIndicator(
                        onRefresh: () => _load(quiet: true),
                        child: ListView(
                          controller: _scroll,
                          padding: const EdgeInsets.all(16),
                          children: [
                            _Summary(request: r),
                            const SizedBox(height: 12),
                            _Actions(
                              key: _actionsKey,
                              request: r,
                              busy: _busy,
                              onConfirm: () => _confirm(r),
                              onDecline: () => _decline(r),
                              onCancelOrder: () => _cancelOrder(r),
                            ),
                            const SizedBox(height: 16),
                            Text('Percakapan',
                                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                            const SizedBox(height: 8),
                            if (_messages.isEmpty)
                              Text(
                                r.status.canMessage
                                    ? 'Belum ada pesan. Balasan pertama Anda mengubah status menjadi "Sudah dibalas".'
                                    : 'Tidak ada pesan.',
                                style: theme.textTheme.bodySmall,
                              ),
                            for (final m in _messages)
                              _Bubble(message: m, renterName: r.renterName ?? 'Penyewa'),
                          ],
                        ),
                      ),
                    ),
                    if (r.status.canMessage)
                      SafeArea(
                        top: false,
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(12, 4, 8, 8),
                          child: Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _input,
                                  minLines: 1,
                                  maxLines: 4,
                                  maxLength: 1000,
                                  decoration: const InputDecoration(
                                    hintText: 'Balas penyewa (ukuran, ambil/kirim, deposit)…',
                                    counterText: '',
                                  ),
                                ),
                              ),
                              IconButton(
                                tooltip: 'Kirim',
                                onPressed: _busy ? null : _send,
                                icon: const Icon(Icons.send),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
    );
  }
}

class _Summary extends StatelessWidget {
  const _Summary({required this.request});
  final StoreRequest request;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final r = request;
    final fmt = DateFormat('EEE, d MMM yyyy', 'id_ID');
    final short = DateFormat('d MMM', 'id_ID');
    final blocked = r.blockStart != null &&
        r.blockEndExclusive != null &&
        (r.blockStart != r.rentStart || r.blockEndExclusive != r.rentEndExclusive);
    final total = r.totalRentIdr ?? r.estimateRentIdr;
    final deposit = r.depositIdr ?? r.estimateDepositIdr;
    final phone = r.renterPhone;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                StatusChip(status: r.status, storeView: true),
                const Spacer(),
                Text('Masuk ${DateFormat('d MMM HH:mm', 'id_ID').format(r.createdAt.toLocal())}',
                    style: theme.textTheme.labelSmall),
              ],
            ),
            if (r.closedReason != null && !r.status.isOpen) ...[
              const SizedBox(height: 6),
              Text('Keterangan: ${declineReasons[r.closedReason] ?? r.closedReason}', style: theme.textTheme.bodySmall),
            ],
            const Divider(height: 20),
            InkWell(
              onTap: () => context.push('/detail/${r.productId}'),
              child: Text(r.productTitle, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            ),
            if (r.size != null) Text('Ukuran ${r.size}'),
            const SizedBox(height: 4),
            Text('${fmt.format(r.rentStart)} – ${fmt.format(r.rentEnd)} (${r.days} hari)'),
            if (blocked)
              Text(
                'Set terkunci ${short.format(r.blockStart!)} – '
                '${short.format(r.blockEndExclusive!.subtract(const Duration(days: 1)))} (termasuk persiapan/laundry)',
                style: theme.textTheme.bodySmall,
              ),
            if (total != null) ...[
              const SizedBox(height: 4),
              Text('${r.totalRentIdr == null ? 'Perkiraan biaya' : 'Biaya sewa'}: ${rupiah(total)}'
                  '${(deposit ?? 0) > 0 ? ' · Deposit ${rupiah(deposit!)}' : ''}'),
            ],
            const Divider(height: 20),
            Text('Penyewa', style: theme.textTheme.labelLarge),
            Text(r.renterName ?? 'Tanpa nama'),
            if (phone != null)
              Wrap(
                spacing: 4,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(phone),
                  TextButton.icon(
                    onPressed: () => launchUrl(Uri.parse('https://wa.me/${phone.replaceAll('+', '')}'),
                        mode: LaunchMode.externalApplication),
                    icon: const Icon(Icons.chat_outlined, size: 18),
                    label: const Text('WhatsApp'),
                  ),
                ],
              )
            else
              Text('Nomor HP tidak dibagikan penyewa. Gunakan pesan di bawah.', style: theme.textTheme.bodySmall),
            if (r.note != null) ...[
              const SizedBox(height: 6),
              Text('Catatan penyewa: ${r.note}', style: theme.textTheme.bodySmall),
            ],
          ],
        ),
      ),
    );
  }
}

class _Actions extends StatelessWidget {
  const _Actions({
    super.key,
    required this.request,
    required this.busy,
    required this.onConfirm,
    required this.onDecline,
    required this.onCancelOrder,
  });

  final StoreRequest request;
  final bool busy;
  final VoidCallback onConfirm;
  final VoidCallback onDecline;
  final VoidCallback onCancelOrder;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final r = request;
    if (r.status.isOpen) {
      final free = r.freeUnits.length;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (r.calendarEnabled)
            Text(
              free > 0
                  ? 'Set kosong pada tanggal ini: $free dari ${r.units.length}.'
                  : 'Tidak ada set kosong pada tanggal ini.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: free > 0 ? Colors.green.shade700 : theme.colorScheme.error,
                fontWeight: FontWeight.w600,
              ),
            )
          else
            Text(
              'Paket toko ini belum termasuk kalender, jadi permintaan tidak bisa dikonfirmasi otomatis. '
              'Jawab lewat pesan, atau tolak bila tidak tersedia.',
              style: theme.textTheme.bodySmall,
            ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: busy ? null : onDecline,
                  icon: const Icon(Icons.close),
                  label: const Text('Tolak'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton.icon(
                  onPressed: busy || !r.calendarEnabled ? null : onConfirm,
                  icon: const Icon(Icons.check),
                  label: const Text('Konfirmasi'),
                ),
              ),
            ],
          ),
        ],
      );
    }
    if (r.status == RequestStatus.accepted && r.orderId != null && r.orderStatus == 'confirmed') {
      return Align(
        alignment: Alignment.centerRight,
        child: TextButton.icon(
          onPressed: busy ? null : onCancelOrder,
          icon: const Icon(Icons.event_busy_outlined),
          label: const Text('Batalkan sewa'),
        ),
      );
    }
    return const SizedBox.shrink();
  }
}

class _ConfirmDialog extends StatefulWidget {
  const _ConfirmDialog({required this.request, required this.freeUnits});
  final StoreRequest request;
  final List<UnitOption> freeUnits;

  @override
  State<_ConfirmDialog> createState() => _ConfirmDialogState();
}

class _ConfirmDialogState extends State<_ConfirmDialog> {
  late String _unitId = widget.freeUnits.first.unitId;

  @override
  Widget build(BuildContext context) {
    final r = widget.request;
    final fmt = DateFormat('d MMM', 'id_ID');
    return AlertDialog(
      title: const Text('Konfirmasi sewa?'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${r.productTitle}${r.size == null ? '' : ' · Ukuran ${r.size}'}\n'
                '${fmt.format(r.rentStart)} – ${fmt.format(r.rentEnd)} untuk ${r.renterName ?? 'penyewa'}.'),
            const SizedBox(height: 8),
            const Text('Tanggal langsung dikunci di kalender dan penyewa diberi tahu.'),
            if (widget.freeUnits.length > 1) ...[
              const SizedBox(height: 12),
              const Text('Pilih set yang dipakai:'),
              RadioGroup<String>(
                groupValue: _unitId,
                onChanged: (v) => setState(() => _unitId = v ?? _unitId),
                child: Column(
                  children: [
                    for (final u in widget.freeUnits)
                      RadioListTile<String>(
                        value: u.unitId,
                        contentPadding: EdgeInsets.zero,
                        title: Text(u.label.isEmpty ? 'Set' : u.label),
                      ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Batal')),
        FilledButton(onPressed: () => Navigator.pop(context, _unitId), child: const Text('Konfirmasi')),
      ],
    );
  }
}

class _DeclineSheet extends StatefulWidget {
  const _DeclineSheet();

  @override
  State<_DeclineSheet> createState() => _DeclineSheetState();
}

class _DeclineSheetState extends State<_DeclineSheet> {
  String _reason = 'dates_unavailable';
  final _message = TextEditingController();

  @override
  void dispose() {
    _message.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 0, 16, 16 + MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Tolak permintaan', style: theme.textTheme.titleLarge),
            const SizedBox(height: 8),
            RadioGroup<String>(
              groupValue: _reason,
              onChanged: (v) => setState(() => _reason = v ?? _reason),
              child: Column(
                children: [
                  for (final e in declineReasons.entries)
                    RadioListTile<String>(value: e.key, title: Text(e.value), contentPadding: EdgeInsets.zero),
                ],
              ),
            ),
            TextField(
              controller: _message,
              maxLength: 1000,
              minLines: 2,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'Pesan untuk penyewa (opsional)',
                hintText: 'Mis. tawarkan tanggal atau kostum lain',
              ),
            ),
            const SizedBox(height: 8),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: theme.colorScheme.error),
              onPressed: () => Navigator.pop(context, (reason: _reason, message: _message.text)),
              child: const Text('Tolak permintaan'),
            ),
          ],
        ),
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.message, required this.renterName});
  final RequestMessage message;
  final String renterName;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final mine = message.fromStore;
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        constraints: const BoxConstraints(maxWidth: 320),
        decoration: BoxDecoration(
          color: mine ? theme.colorScheme.primaryContainer : theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(mine ? 'Toko' : renterName,
                style: theme.textTheme.labelSmall?.copyWith(fontWeight: FontWeight.bold)),
            Text(message.body),
            Text(
              DateFormat('d MMM HH:mm', 'id_ID').format(message.createdAt.toLocal()),
              style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}
