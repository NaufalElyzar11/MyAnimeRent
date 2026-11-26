import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/rental_request.dart';
import '../providers/rental_provider.dart';

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
    final theme = Theme.of(context);
    final items = provider.requests;

    return Scaffold(
      appBar: AppBar(title: const Text('Permintaan Sewa')),
      body: RefreshIndicator(
        onRefresh: () => context.read<RentalProvider>().loadRequests(),
        child: provider.isLoading && items.isEmpty
            ? const Center(child: CircularProgressIndicator())
            : items.isEmpty
                ? ListView(
                    padding: const EdgeInsets.all(32),
                    children: [
                      const SizedBox(height: 60),
                      Icon(Icons.receipt_long_outlined, size: 64, color: theme.colorScheme.primary),
                      const SizedBox(height: 16),
                      Text(
                        provider.message ?? 'Belum ada permintaan sewa',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Pilih kostum, tentukan tanggal, lalu tekan "Ajukan sewa". Kabar dari toko muncul di sini.',
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      Center(
                        child: ElevatedButton(onPressed: () => context.go('/home'), child: const Text('Cari kostum')),
                      ),
                    ],
                  )
                : ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: items.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 12),
                    itemBuilder: (context, i) => RequestTile(request: items[i]),
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
  const StatusChip({super.key, required this.status});
  final RequestStatus status;

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
      child: Text(status.label, style: TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 12)),
    );
  }
}
