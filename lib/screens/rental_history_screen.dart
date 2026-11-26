import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/rental_request.dart';
import '../config/theme.dart';
import '../providers/rental_provider.dart';
import '../widgets/ui_kit.dart';

/// "Permintaan Sewa": semua permintaan milik penyewa beserta statusnya.
class RentalHistoryScreen extends StatefulWidget {
  const RentalHistoryScreen({super.key});

  @override
  State<RentalHistoryScreen> createState() => _RentalHistoryScreenState();
}

class _RentalHistoryScreenState extends State<RentalHistoryScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => context.read<RentalProvider>().loadRequests());
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<RentalProvider>();
    final items = provider.requests;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    bool isActive(RentalRequest r) =>
        r.status.isOpen || (r.status == RequestStatus.accepted && r.rentEndExclusive.isAfter(today));
    final active = items.where(isActive).toList();
    final history = items.where((r) => !isActive(r)).toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Permintaan Sewa')),
      body: RefreshIndicator(
        onRefresh: () => context.read<RentalProvider>().loadRequests(),
        child: provider.isLoading && items.isEmpty
            ? ListView(
                padding: const EdgeInsets.all(AppSpacing.page),
                children: [for (var i = 0; i < 4; i++) const Padding(padding: EdgeInsets.only(bottom: 12), child: SkeletonBox(height: 90))],
              )
            : items.isEmpty
                ? ListView(
                    children: [
                      const SizedBox(height: 40),
                      EmptyState(
                        icon: Icons.receipt_long_outlined,
                        title: provider.message ?? 'Belum ada permintaan sewa',
                        message: 'Pilih kostum, tentukan tanggal, lalu tekan "Ajukan sewa". Kabar dari toko muncul di sini.',
                        actionLabel: 'Cari kostum',
                        onAction: () => context.go('/home'),
                      ),
                    ],
                  )
                : ListView(
                    padding: const EdgeInsets.fromLTRB(AppSpacing.page, 4, AppSpacing.page, 24),
                    children: [
                      if (active.isNotEmpty) ...[
                        SectionHeader(title: 'Sedang berjalan', subtitle: '${active.length} permintaan'),
                        for (final r in active) Padding(padding: const EdgeInsets.only(bottom: 10), child: RequestTile(request: r)),
                        const SizedBox(height: 14),
                      ],
                      if (history.isNotEmpty) ...[
                        const SectionHeader(title: 'Riwayat'),
                        for (final r in history) Padding(padding: const EdgeInsets.only(bottom: 10), child: RequestTile(request: r)),
                      ],
                    ],
                  ),
      ),
    );
  }
}

class RequestTile extends StatelessWidget {
  const RequestTile({super.key, required this.request});
  final RentalRequest request;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final r = request;
    final fmt = DateFormat('d MMM', 'id_ID');
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push('/requests/${r.id}'),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: SizedBox(
                  width: 64,
                  height: 64,
                  child: r.coverUrl.isEmpty
                      ? Container(color: theme.colorScheme.surfaceContainerHighest, child: const Icon(Icons.checkroom))
                      : CachedNetworkImage(
                          imageUrl: r.coverUrl,
                          fit: BoxFit.cover,
                          errorWidget: (_, _, _) => const Icon(Icons.checkroom),
                        ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(r.productTitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
                    Text('${r.storeName}${r.size == null ? '' : ' · Ukuran ${r.size}'}', style: theme.textTheme.bodySmall),
                    Text('${fmt.format(r.rentStart)} – ${fmt.format(r.rentEnd)} · ${r.code}', style: theme.textTheme.bodySmall),
                    const SizedBox(height: 6),
                    StatusChip(status: r.status),
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

class StatusChip extends StatelessWidget {
  const StatusChip({super.key, required this.status, this.storeView = false});
  final RequestStatus status;

  /// Label dari sisi toko ("Baru", "Sudah dibalas") alih-alih sisi penyewa.
  final bool storeView;

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      RequestStatus.accepted => Colors.green.shade700,
      RequestStatus.responded => Colors.blue.shade700,
      RequestStatus.submitted => Colors.orange.shade800,
      _ => Colors.grey.shade700,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(storeView ? status.storeLabel : status.label, style: TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 12)),
    );
  }
}
