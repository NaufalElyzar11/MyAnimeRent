import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import '../providers/costume_provider.dart';
import '../providers/wishlist_provider.dart';
import '../providers/review_provider.dart';
import '../providers/rental_provider.dart';
import '../models/costume.dart';
import '../models/store.dart';
import '../services/auth_service.dart';
import '../widgets/review_section.dart';
import '../widgets/review_dialog.dart';
import '../widgets/expandable_calendar_view.dart';

class ProductDetailScreen extends StatefulWidget {
  final String costumeId;
  const ProductDetailScreen({super.key, required this.costumeId});

  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen> {
  Costume? _costume;
  Store? _store;
  bool _isLoading = true;
  bool _isWishlisted = false;
  bool _isBooking = false;
  DateTime? _startDate;
  DateTime? _endDate;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final costumeProvider = context.read<CostumeProvider>();
    final wishlistProvider = context.read<WishlistProvider>();
    final reviewProvider = context.read<ReviewProvider>();

    // 1. Fetch costume & store (instant from cache if already loaded)
    final costume = await costumeProvider.getCostumeById(widget.costumeId);
    Store? store;
    if (costume != null) {
      store = await costumeProvider.getStoreById(costume.storeId);
    }

    if (mounted) {
      setState(() {
        _costume = costume;
        _store = store;
        _isLoading = false;
      });
    }

    // 2. Load reviews and wishlist in background (non-blocking)
    if (costume != null) {
      reviewProvider.loadReviewsForCostume(widget.costumeId);
    }
    wishlistProvider.isWishlisted(widget.costumeId).then((wishlisted) {
      if (mounted) {
        setState(() {
          _isWishlisted = wishlisted;
        });
      }
    }).catchError((_) {});
  }

  Future<void> _selectDateRange() async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final range = await showDateRangePicker(
      context: context,
      firstDate: today,
      lastDate: today.add(const Duration(days: 365)),
    );

    if (range != null) {
      final days = range.end.difference(range.start).inDays + 1;
      if (days < 3) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Minimum rental is 3 days')),
          );
        }
        return;
      }

      // Check if any date within range is already booked
      final bookedDates = _costume?.bookedDates ?? [];
      bool hasOverlap = false;
      var curr = DateTime(range.start.year, range.start.month, range.start.day);
      final end = DateTime(range.end.year, range.end.month, range.end.day);
      while (!curr.isAfter(end)) {
        final dateStr =
            "${curr.year.toString().padLeft(4, '0')}-${curr.month.toString().padLeft(2, '0')}-${curr.day.toString().padLeft(2, '0')}";
        if (bookedDates.contains(dateStr)) {
          hasOverlap = true;
          break;
        }
        curr = curr.add(const Duration(days: 1));
      }

      if (hasOverlap) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                  'Beberapa tanggal yang dipilih sudah di-booking. Silakan pilih tanggal lain.'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      setState(() {
        _startDate = range.start;
        _endDate = range.end;
      });
    }
  }

  Future<void> _handleBookNow() async {
    if (_startDate == null || _endDate == null || _costume == null) return;

    final bookedDates = _costume!.bookedDates;
    final datesToAdd = <String>[];
    var curr = DateTime(_startDate!.year, _startDate!.month, _startDate!.day);
    final end = DateTime(_endDate!.year, _endDate!.month, _endDate!.day);
    bool hasOverlap = false;

    while (!curr.isAfter(end)) {
      final dateStr =
          "${curr.year.toString().padLeft(4, '0')}-${curr.month.toString().padLeft(2, '0')}-${curr.day.toString().padLeft(2, '0')}";
      if (bookedDates.contains(dateStr)) {
        hasOverlap = true;
        break;
      }
      datesToAdd.add(dateStr);
      curr = curr.add(const Duration(days: 1));
    }

    if (hasOverlap) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'Kostum sudah di-booking pada rentang tanggal tersebut. Silakan pilih tanggal lain.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isBooking = true);

    final days = _endDate!.difference(_startDate!).inDays + 1;
    final total = _costume!.price * days;

    final success = await context.read<RentalProvider>().createRental(
          costumeId: _costume!.id,
          startDate: _startDate!,
          endDate: _endDate!,
          totalPrice: total,
        );

    if (!mounted) return;
    setState(() => _isBooking = false);

    if (success) {
      // Immediately reflect new booked dates in local state
      setState(() {
        _costume = _costume!.copyWith(
          bookedDates: {..._costume!.bookedDates, ...datesToAdd}.toList(),
        );
        _startDate = null;
        _endDate = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Rental created successfully!'),
          backgroundColor: Colors.green,
        ),
      );
    } else {
      final msg =
          context.read<RentalProvider>().message ?? 'Failed to create rental';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final reviewProvider = context.watch<ReviewProvider>();
    final currentUserId = AuthService().currentUser?.uid;

    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_costume == null) {
      return const Scaffold(
        body: Center(child: Text('Costume not found')),
      );
    }

    final costume = _costume!;
    final formatter = NumberFormat('#,###', 'id_ID');

    return Scaffold(
      body: Stack(
        children: [
          SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Image Carousel
                SizedBox(
                  height: 400,
                  child: Stack(
                    children: [
                      PageView.builder(
                        itemCount: costume.imageUrls.length,
                        itemBuilder: (_, index) {
                          return CachedNetworkImage(
                            imageUrl: costume.imageUrls[index],
                            fit: BoxFit.cover,
                            width: double.infinity,
                            errorWidget: (context, url, error) => Container(
                              color: theme.colorScheme.surfaceContainerHighest,
                              child: const Icon(Icons.image_not_supported, size: 60),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),

                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(costume.name,
                          style: theme.textTheme.headlineMedium
                              ?.copyWith(fontWeight: FontWeight.bold)),
                      Text('From: ${costume.anime}',
                          style: theme.textTheme.titleMedium
                              ?.copyWith(color: theme.colorScheme.primary)),
                      const SizedBox(height: 8),
                      Text('Rp ${formatter.format(costume.price.toInt())}',
                          style: theme.textTheme.titleLarge
                              ?.copyWith(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 16),

                      // Store Info
                      if (_store != null) ...[
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surfaceContainerHighest
                                .withValues(alpha: 0.5),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: CachedNetworkImage(
                                  imageUrl: _store!.imageUrl,
                                  width: 56,
                                  height: 56,
                                  fit: BoxFit.cover,
                                  errorWidget: (context, url, error) =>
                                      const Icon(Icons.store, size: 28),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(_store!.name,
                                        style: theme.textTheme.titleMedium
                                            ?.copyWith(fontWeight: FontWeight.bold)),
                                    Text(_store!.city,
                                        style: theme.textTheme.bodyMedium?.copyWith(
                                            color: theme.colorScheme.onSurfaceVariant)),
                                  ],
                                ),
                              ),
                              ElevatedButton(
                                onPressed: () =>
                                    context.push('/store_detail/${_store!.id}'),
                                child: const Text('Visit'),
                              ),
                            ],
                          ),
                        ),
                      ],

                      const SizedBox(height: 16),
                      Text('Description',
                          style: theme.textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Text(costume.description, style: theme.textTheme.bodyLarge),

                      const SizedBox(height: 16),
                      Text('Available Sizes: ${costume.sizes.join(", ")}',
                          style: theme.textTheme.bodyLarge
                              ?.copyWith(fontWeight: FontWeight.w500)),

                      const SizedBox(height: 24),

                      // Date Selection Calendar
                      Text('Select Rental Dates (min. 3 days)',
                          style: theme.textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      ExpandableCalendarView(
                        bookedDates: costume.bookedDates,
                        selectedStartDate: _startDate,
                        selectedEndDate: _endDate,
                        onDateRangeSelected: (start, end) {
                          setState(() {
                            _startDate = start;
                            _endDate = end;
                          });
                        },
                        onSelectionInvalid: (msg) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(msg),
                              backgroundColor: Colors.red.shade700,
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              _startDate != null && _endDate != null
                                  ? '${DateFormat('dd MMM').format(_startDate!)} - ${DateFormat('dd MMM yyyy').format(_endDate!)} (${_endDate!.difference(_startDate!).inDays + 1} days)'
                                  : 'Tap a date to select a 3-day rental',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: _startDate != null
                                    ? theme.colorScheme.primary
                                    : theme.colorScheme.onSurface
                                        .withValues(alpha: 0.6),
                              ),
                            ),
                          ),
                          TextButton.icon(
                            onPressed: _selectDateRange,
                            icon: const Icon(Icons.date_range, size: 18),
                            label: const Text('Custom Range'),
                          ),
                        ],
                      ),

                      const SizedBox(height: 24),

                      // Reviews
                      ReviewSection(
                        reviews: reviewProvider.reviews,
                        currentUserId: currentUserId,
                        onEditReview: (review) {
                          showDialog(
                            context: context,
                            builder: (_) => ReviewDialog(
                              onDismiss: () => Navigator.pop(context),
                              onSubmit: (text, cr, sr) {
                                reviewProvider.updateReview(
                                    reviewId: review.id,
                                    costumeId: widget.costumeId,
                                    text: text,
                                    costumeRating: cr,
                                    storeRating: sr);
                              },
                            ),
                          );
                        },
                        onDeleteReview: (reviewId) {
                          reviewProvider.deleteReview(reviewId, widget.costumeId);
                        },
                      ),

                      const SizedBox(height: 100),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Top bar (back + wishlist)
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  CircleAvatar(
                    backgroundColor: Colors.white.withValues(alpha: 0.85),
                    child: IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.black87),
                      onPressed: () => context.pop(),
                    ),
                  ),
                  CircleAvatar(
                    backgroundColor: Colors.white.withValues(alpha: 0.85),
                    child: IconButton(
                      icon: Icon(
                        _isWishlisted ? Icons.favorite : Icons.favorite_border,
                        color: _isWishlisted ? Colors.red : Colors.black87,
                      ),
                      onPressed: () async {
                        final messenger = ScaffoldMessenger.of(context);
                        final newStatus = await context
                            .read<WishlistProvider>()
                            .toggleWishlist(widget.costumeId);
                        if (mounted) {
                          setState(() => _isWishlisted = newStatus);
                          messenger.showSnackBar(
                            SnackBar(
                              content: Text(
                                newStatus
                                    ? 'Added to wishlist!'
                                    : 'Removed from wishlist',
                              ),
                              duration: const Duration(seconds: 2),
                            ),
                          );
                        }
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Book Now button
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.all(16),
              color: theme.scaffoldBackgroundColor,
              child: SizedBox(
                height: 56,
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: (_startDate != null && _endDate != null && !_isBooking)
                      ? _handleBookNow
                      : null,
                  child: _isBooking
                      ? const SizedBox(
                          height: 24,
                          width: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Book Now', style: TextStyle(fontSize: 18)),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
