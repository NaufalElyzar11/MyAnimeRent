import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import '../providers/rental_provider.dart';
import '../providers/review_provider.dart';
import '../widgets/review_dialog.dart';

class RentalHistoryScreen extends StatefulWidget {
  const RentalHistoryScreen({super.key});

  @override
  State<RentalHistoryScreen> createState() => _RentalHistoryScreenState();
}

class _RentalHistoryScreenState extends State<RentalHistoryScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<RentalProvider>().loadRentalHistory();
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<RentalProvider>();
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Rental History'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: () => context.read<RentalProvider>().loadRentalHistory(),
        child: provider.isLoading
            ? const Center(child: CircularProgressIndicator())
            : provider.rentals.isEmpty
                ? LayoutBuilder(
                    builder: (context, constraints) => SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      child: ConstrainedBox(
                        constraints:
                            BoxConstraints(minHeight: constraints.maxHeight),
                        child: Center(
                          child: Padding(
                            padding: const EdgeInsets.all(32),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Container(
                                  width: 90,
                                  height: 90,
                                  decoration: BoxDecoration(
                                    color: theme.colorScheme.primary
                                        .withValues(alpha: 0.12),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    Icons.receipt_long_outlined,
                                    size: 48,
                                    color: theme.colorScheme.primary,
                                  ),
                                ),
                                const SizedBox(height: 20),
                                Text(
                                  'Belum Ada Riwayat Sewa',
                                  style: theme.textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Kostum yang kamu sewa untuk event atau cosplay akan tercatat rapi di sini.',
                                  textAlign: TextAlign.center,
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant,
                                    height: 1.4,
                                  ),
                                ),
                                const SizedBox(height: 24),
                                ElevatedButton.icon(
                                  onPressed: () => context.go('/home'),
                                  icon: const Icon(Icons.shopping_bag_outlined,
                                      size: 18),
                                  label: const Text('Mulai Sewa Kostum'),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  )
                : ListView.separated(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(16),
                    itemCount: provider.rentals.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                    final item = provider.rentals[index];
                    final dateFormatter = DateFormat('dd MMM yyyy');
                    final priceFormatter = NumberFormat('#,###', 'id_ID');

                    Color statusBgColor;
                    Color statusTextColor;
                    String statusLabel;

                    switch (item.status.name) {
                      case 'active':
                        statusBgColor = Colors.blue.withValues(alpha: 0.15);
                        statusTextColor = Colors.blue.shade700;
                        statusLabel = 'Active';
                        break;
                      case 'completed':
                        statusBgColor = Colors.green.withValues(alpha: 0.15);
                        statusTextColor = Colors.green.shade700;
                        statusLabel = 'Completed';
                        break;
                      case 'cancelled':
                        statusBgColor = Colors.red.withValues(alpha: 0.15);
                        statusTextColor = Colors.red.shade700;
                        statusLabel = 'Cancelled';
                        break;
                      case 'pending':
                      default:
                        statusBgColor = Colors.orange.withValues(alpha: 0.15);
                        statusTextColor = Colors.orange.shade800;
                        statusLabel = 'Pending';
                        break;
                    }

                    return Card(
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Status Header
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: statusBgColor,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    statusLabel,
                                    style: TextStyle(
                                      color: statusTextColor,
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                if (item.totalPrice > 0)
                                  Text(
                                    'Rp ${priceFormatter.format(item.totalPrice.toInt())}',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: theme.colorScheme.primary,
                                      fontSize: 15,
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(10),
                                  child: CachedNetworkImage(
                                    imageUrl: item.costume.imageUrls.isNotEmpty
                                        ? item.costume.imageUrls.first
                                        : '',
                                    width: 76,
                                    height: 76,
                                    fit: BoxFit.cover,
                                    errorWidget: (context, url, error) =>
                                        Container(
                                      width: 76,
                                      height: 76,
                                      color: theme
                                          .colorScheme.surfaceContainerHighest,
                                      child: const Icon(Icons.image),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        item.costume.name,
                                        style: theme.textTheme.titleMedium
                                            ?.copyWith(
                                                fontWeight: FontWeight.bold),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      Text(
                                        item.costume.anime,
                                        style: theme.textTheme.bodySmall
                                            ?.copyWith(
                                          color:
                                              theme.colorScheme.onSurfaceVariant,
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      if (item.size != null &&
                                          item.size!.isNotEmpty) ...[
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 8, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: theme.colorScheme.primary
                                                .withValues(alpha: 0.1),
                                            borderRadius:
                                                BorderRadius.circular(6),
                                          ),
                                          child: Text(
                                            'Size: ${item.size}',
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w600,
                                              color: theme.colorScheme.primary,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(height: 6),
                                      ],
                                      Text(
                                        '${dateFormatter.format(item.startDate)} - ${dateFormatter.format(item.endDate)}',
                                        style: theme.textTheme.bodySmall
                                            ?.copyWith(
                                          color:
                                              theme.colorScheme.onSurfaceVariant,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            const Divider(height: 1),
                            const SizedBox(height: 8),
                            if (!provider.isReviewed(item))
                              Align(
                                alignment: Alignment.centerRight,
                                child: ElevatedButton.icon(
                                  onPressed: () {
                                    showDialog(
                                      context: context,
                                      builder: (_) => ReviewDialog(
                                        onDismiss: () => Navigator.pop(context),
                                        onSubmit: (text, cr, sr) async {
                                          final rentalKey =
                                              item.endDate.toIso8601String();
                                          await context
                                              .read<ReviewProvider>()
                                              .createReview(
                                                costumeId: item.costume.id,
                                                storeId: item.costume.storeId,
                                                rentalId: rentalKey,
                                                text: text,
                                                costumeRating: cr,
                                                storeRating: sr,
                                              );
                                          if (context.mounted) {
                                            context
                                                .read<RentalProvider>()
                                                .markAsReviewed(rentalKey);
                                            if (item.id.isNotEmpty) {
                                              context
                                                  .read<RentalProvider>()
                                                  .markAsReviewed(item.id);
                                            }
                                            ScaffoldMessenger.of(context)
                                                .showSnackBar(
                                              const SnackBar(
                                                content: Text(
                                                    'Review submitted successfully!'),
                                                backgroundColor: Colors.green,
                                              ),
                                            );
                                          }
                                        },
                                      ),
                                    );
                                  },
                                  icon: const Icon(Icons.rate_review, size: 16),
                                  label: const Text('Write Review'),
                                  style: ElevatedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 14, vertical: 8),
                                    textStyle: const TextStyle(fontSize: 13),
                                  ),
                                ),
                              )
                            else
                              Align(
                                alignment: Alignment.centerRight,
                                child: TextButton.icon(
                                  onPressed: null,
                                  icon: const Icon(Icons.check_circle,
                                      size: 16, color: Colors.green),
                                  label: const Text('Reviewed',
                                      style: TextStyle(color: Colors.green)),
                                ),
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
      ),
    );
  }
}
