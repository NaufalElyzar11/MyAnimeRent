import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/review.dart';

class ReviewSection extends StatelessWidget {
  final List<Review> reviews;
  final String? currentUserId;
  final void Function(Review) onEditReview;
  final void Function(String) onDeleteReview;

  const ReviewSection({
    super.key,
    required this.reviews,
    required this.currentUserId,
    required this.onEditReview,
    required this.onDeleteReview,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Reviews (${reviews.length})',
          style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        if (reviews.isEmpty)
          Text(
            'No reviews yet',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          )
        else
          ...reviews.map((review) => Column(
                children: [
                  _ReviewItem(
                    review: review,
                    isCurrentUser: currentUserId == review.userId,
                    onEdit: () => onEditReview(review),
                    onDelete: () => onDeleteReview(review.id),
                  ),
                  const Divider(),
                ],
              )),
      ],
    );
  }
}

class _ReviewItem extends StatelessWidget {
  final Review review;
  final bool isCurrentUser;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _ReviewItem({
    required this.review,
    required this.isCurrentUser,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundImage: review.userPhotoUrl != null
                    ? CachedNetworkImageProvider(review.userPhotoUrl!)
                    : null,
                child: review.userPhotoUrl == null
                    ? const Icon(Icons.person, size: 20)
                    : null,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      review.userName.isNotEmpty ? review.userName : 'Anonymous',
                      style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    Row(
                      children: [
                        Text('Costume: ${review.costumeRating.toStringAsFixed(0)}',
                            style: theme.textTheme.bodySmall),
                        Icon(Icons.star, size: 14, color: theme.colorScheme.primary),
                        const SizedBox(width: 8),
                        Text('Store: ${review.storeRating.toStringAsFixed(0)}',
                            style: theme.textTheme.bodySmall),
                        Icon(Icons.star, size: 14, color: theme.colorScheme.primary),
                      ],
                    ),
                  ],
                ),
              ),
              if (isCurrentUser) ...[
                IconButton(
                  icon: const Icon(Icons.edit, size: 20),
                  onPressed: onEdit,
                ),
                IconButton(
                  icon: const Icon(Icons.delete, size: 20),
                  onPressed: onDelete,
                ),
              ],
            ],
          ),
          const SizedBox(height: 4),
          Text(
            review.text.isNotEmpty ? review.text : 'No comment',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
