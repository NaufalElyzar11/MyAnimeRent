import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/app_notification.dart';
import '../models/rental_request.dart';
import '../providers/notification_provider.dart';
import '../providers/rental_provider.dart';
import '../services/database_service.dart';
import '../services/supabase_service.dart';
import 'product_detail_screen.dart' show rupiah;
import 'rental_history_screen.dart' show StatusChip;

/// Detail satu permintaan: status, rincian, percakapan dengan toko, dan pembatalan.
class RequestDetailScreen extends StatefulWidget {
  const RequestDetailScreen({super.key, required this.requestId});
  final String requestId;

  @override
  State<RequestDetailScreen> createState() => _RequestDetailScreenState();
}

class _RequestDetailScreenState extends State<RequestDetailScreen> {
  final _db = DatabaseService();
  final _input = TextEditingController();
  final _scroll = ScrollController();
  RentalRequest? _request;
  List<RequestMessage> _messages = [];
  bool _loading = true;
  bool _sending = false;
  String? _error;
  String? _pendingOperation; // dipakai ulang bila kirim pesan gagal karena jaringan
  NotificationProvider? _notifications;

  @override
  void initState() {
    super.initState();
    _load();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final n = context.read<NotificationProvider>();
      _notifications = n;
      _lastSeen = n.items.where((x) => x.requestId == widget.requestId).length;
      n.addListener(_onNotification);
      _markRelatedRead();
    });
  }

  int _lastSeen = 0;

  /// Notifikasi baru untuk permintaan ini → muat ulang status & pesan.
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
        _db.getMyRequest(widget.requestId),
        _db.getMessages(widget.requestId),
      ]);
      if (!mounted) return;
      setState(() {
        _request = results[0] as RentalRequest?;
        _messages = results[1] as List<RequestMessage>;
        _error = null;
        _loading = false;
      });
      _markRelatedRead();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  void _markRelatedRead() {
    final n = _notifications;
    if (n == null) return;
    for (final item in n.items.where((x) => x.requestId == widget.requestId && !x.isRead)) {
      n.markRead(item);
    }
  }

  Future<void> _send() async {
    final text = _input.text.trim();
    if (text.isEmpty || _sending) return;
    _pendingOperation ??= newOperationId();
    setState(() => _sending = true);
    try {
      await _db.postMessage(widget.requestId, text, operationId: _pendingOperation!);
      _pendingOperation = null;
      _input.clear();
      await _load(quiet: true);
      if (_scroll.hasClients) {
        _scroll.animateTo(_scroll.position.maxScrollExtent,
            duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
      }
    } on ApiException catch (e) {
      if (!e.isNetwork) _pendingOperation = null;
      _snack(e.message, error: true);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _cancel(RentalRequest r) async {
    final reason = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Batalkan permintaan?'),
        content: TextField(
          controller: reason,
          maxLength: 200,
          decoration: const InputDecoration(labelText: 'Alasan (opsional)'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Tidak')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Batalkan')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      await context.read<RentalProvider>().cancel(r, operationId: newOperationId(), reason: reason.text.trim());
      _snack('Permintaan dibatalkan. Toko sudah diberi tahu.');
      await _load(quiet: true);
    } on ApiException catch (e) {
      _snack(e.reason == 'STALE_REVISION' ? 'Status permintaan baru saja berubah. Data dimuat ulang.' : e.message,
          error: true);
      await _load(quiet: true);
    }
  }

  void _snack(String msg, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg), backgroundColor: error ? Colors.red.shade700 : null));
  }

  String _statusText(RentalRequest r) => switch (r.status) {
        RequestStatus.submitted => 'Permintaan terkirim. Menunggu jawaban toko.',
        RequestStatus.responded => 'Toko sudah membalas. Lanjutkan percakapan di bawah.',
        RequestStatus.accepted => 'Dikonfirmasi toko — tanggal sudah dikunci untukmu.',
        RequestStatus.declined => 'Ditolak toko${r.closedReason == null ? '' : ': ${r.closedReason}'}.',
        RequestStatus.cancelled => r.closedBy == 'renter'
            ? 'Kamu membatalkan permintaan ini.'
            : 'Dibatalkan toko${r.closedReason == null ? '' : ': ${r.closedReason}'}.',
        RequestStatus.expired => 'Kedaluwarsa: toko belum mengonfirmasi sebelum tanggal sewa.',
      };

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
                    Expanded(
                      child: RefreshIndicator(
                        onRefresh: () => _load(quiet: true),
                        child: ListView(
                          controller: _scroll,
                          padding: const EdgeInsets.all(16),
                          children: [
                            _Summary(request: r, statusText: _statusText(r)),
                            if (r.status.isOpen)
                              Align(
                                alignment: Alignment.centerRight,
                                child: TextButton.icon(
                                  onPressed: () => _cancel(r),
                                  icon: const Icon(Icons.cancel_outlined),
                                  label: const Text('Batalkan permintaan'),
                                ),
                              ),
                            if (r.status == RequestStatus.accepted && r.storeWhatsapp != null)
                              Align(
                                alignment: Alignment.centerRight,
                                child: TextButton.icon(
                                  onPressed: () => launchUrl(
                                    Uri.parse('https://wa.me/${r.storeWhatsapp!.replaceAll('+', '')}'),
                                    mode: LaunchMode.externalApplication,
                                  ),
                                  icon: const Icon(Icons.chat_outlined),
                                  label: const Text('Hubungi toko'),
                                ),
                              ),
                            const SizedBox(height: 8),
                            Text('Percakapan', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                            const SizedBox(height: 8),
                            if (_messages.isEmpty)
                              Text('Belum ada pesan. Tanyakan ukuran, cara ambil/kirim, atau deposit di sini.',
                                  style: theme.textTheme.bodySmall),
                            for (final m in _messages) _Bubble(message: m, storeName: r.storeName),
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
                                  textInputAction: TextInputAction.newline,
                                  decoration: const InputDecoration(
                                    hintText: 'Tulis pesan untuk toko…',
                                    counterText: '',
                                  ),
                                ),
                              ),
                              IconButton(
                                tooltip: 'Kirim',
                                onPressed: _sending ? null : _send,
                                icon: _sending
                                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                                    : const Icon(Icons.send),
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
  const _Summary({required this.request, required this.statusText});
  final RentalRequest request;
  final String statusText;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final r = request;
    final fmt = DateFormat('EEE, d MMM yyyy', 'id_ID');
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            StatusChip(status: r.status),
            const SizedBox(height: 8),
            Text(statusText),
            const Divider(height: 20),
            InkWell(
              onTap: () => context.push('/detail/${r.productId}'),
              child: Text(r.productTitle, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            ),
            Text('${r.storeName}${r.size == null ? '' : ' · Ukuran ${r.size}'}'),
            const SizedBox(height: 4),
            Text('${fmt.format(r.rentStart)} – ${fmt.format(r.rentEnd)} (${r.days} hari)'),
            if (r.totalRentIdr != null) ...[
              const SizedBox(height: 4),
              Text('Biaya sewa: ${rupiah(r.totalRentIdr!)}'
                  '${(r.depositIdr ?? 0) > 0 ? ' · Deposit ${rupiah(r.depositIdr!)}' : ''}'),
            ],
            if (r.note != null && r.note!.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text('Catatanmu: ${r.note}', style: theme.textTheme.bodySmall),
            ],
          ],
        ),
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.message, required this.storeName});
  final RequestMessage message;
  final String storeName;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final mine = !message.fromStore;
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
            if (!mine) Text(storeName, style: theme.textTheme.labelSmall?.copyWith(fontWeight: FontWeight.bold)),
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
