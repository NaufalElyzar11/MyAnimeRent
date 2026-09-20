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
      body: provider.isLoading
          ? const Center(child: CircularProgressIndicator())
          : provider.rentals.isEmpty
              ? const Center(child: Text('No rental history found.'))
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: provider.rentals.length,
                  separatorBuilder: (context, index) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final item = provider.rentals[index];
                    final formatter = DateFormat('dd MMM yyyy');

                    return Card(
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: CachedNetworkImage(
                                    imageUrl: item.costume.imageUrls.isNotEmpty
                                        ? item.costume.imageUrls.first
                                        : '',
                                    width: 80,
                                    height: 80,
                                    fit: BoxFit.cover,
                                    errorWidget: (context, url, error) => Container(
                                      width: 80,
                                      height: 80,
                                      color: theme.colorScheme.surfaceContainerHighest,
                                      child: const Icon(Icons.image),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        item.costume.name,
                                        style: theme.textTheme.titleMedium
                                            ?.copyWith(fontWeight: FontWeight.bold),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'Rented from: ${formatter.format(item.startDate)}',
                                        style: theme.textTheme.bodyMedium,
                                      ),
                                      Text(
                                        'To: ${formatter.format(item.endDate)}',
                                        style: theme.textTheme.bodyMedium,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            if (!provider.isReviewed(item))
                              Align(
                                alignment: Alignment.centerRight,
                                child: ElevatedButton(
                                  onPressed: () {
                                    showDialog(
                                      context: context,
                                      builder: (_) => ReviewDialog(
                                        onDismiss: () => Navigator.pop(context),
                                        onSubmit: (text, cr, sr) async {
                                          final rentalKey = item.endDate.toIso8601String();
                                          await context.read<ReviewProvider>().createReview(
                                                costumeId: item.costume.id,
                                                storeId: item.costume.storeId,
                                                rentalId: rentalKey,
                                                text: text,
                                                costumeRating: cr,
                                                storeRating: sr,
                                              );
                                          if (context.mounted) {
                                            context.read<RentalProvider>().markAsReviewed(rentalKey);
                                            if (item.id.isNotEmpty) {
                                              context.read<RentalProvider>().markAsReviewed(item.id);
                                            }
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              const SnackBar(
                                                content: Text('Review submitted successfully!'),
                                                backgroundColor: Colors.green,
                                              ),
                                            );
                                          }
                                        },
                                      ),
                                    );
                                  },
                                  child: const Text('Write Review'),
                                ),
                              )
                            else
                              Align(
                                alignment: Alignment.centerRight,
                                child: ElevatedButton(
                                  onPressed: null,
                                  style: ElevatedButton.styleFrom(
                                    disabledBackgroundColor: Colors.grey.shade300,
                                    disabledForegroundColor: Colors.grey.shade600,
                                    elevation: 0,
                                  ),
                                  child: const Text('Reviewed'),
                                ),
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
