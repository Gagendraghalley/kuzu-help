import 'package:flutter/material.dart';

import '../../core/strings/app_strings.dart';
import '../models/review.dart';
import 'star_rating.dart';

/// One review: stars, date and comment (C3, B5).
class ReviewTile extends StatelessWidget {
  final Review review;

  const ReviewTile({super.key, required this.review});

  @override
  Widget build(BuildContext context) {
    final comment = review.comment;
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              StarRating(rating: review.rating.toDouble()),
              const Spacer(),
              Text(
                AppStrings.shortDate(review.createdAt),
                style: text.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
              ),
            ],
          ),
          if (comment != null && comment.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(comment, style: text.bodyLarge),
          ],
        ],
      ),
    );
  }
}
