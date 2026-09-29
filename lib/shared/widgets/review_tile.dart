import 'package:flutter/material.dart';

import '../../core/strings/app_strings.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/error_messages.dart';
import '../models/review.dart';
import 'star_rating.dart';
import 'text_dialog.dart';

/// One review: stars, date, comment and the worker's reply (C3, B5). The
/// worker who was reviewed gets a Reply button ([onReply]).
class ReviewTile extends StatelessWidget {
  final Review review;
  final VoidCallback? onReply;

  const ReviewTile({super.key, required this.review, this.onReply});

  @override
  Widget build(BuildContext context) {
    final comment = review.comment;
    final reply = review.reply;
    final text = Theme.of(context).textTheme;
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    final onReply = this.onReply;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              StarRating(rating: review.rating.toDouble()),
              const Spacer(),
              Text(AppStrings.shortDate(review.createdAt), style: text.bodySmall?.copyWith(color: muted)),
            ],
          ),
          if (comment != null && comment.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(comment, style: text.bodyLarge),
          ],
          if (reply != null && reply.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: AppColors.ivory, borderRadius: BorderRadius.circular(12)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(AppStrings.replyFromWorker,
                      style: text.labelLarge?.copyWith(color: AppColors.primaryDeep)),
                  const SizedBox(height: 4),
                  Text(reply),
                ],
              ),
            ),
          ],
          if (onReply != null)
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                icon: const Icon(Icons.reply),
                label: Text(reply == null ? AppStrings.reply : AppStrings.editReply),
                onPressed: onReply,
              ),
            ),
        ],
      ),
    );
  }
}

/// The reviewed worker writes or changes their reply; true when saved.
Future<bool> replyToReview(
  BuildContext context,
  Review review,
  Future<void> Function(String reply) save,
) async {
  final reply = await showTextDialog(
    context,
    title: AppStrings.replyTitle,
    hint: AppStrings.replyHint,
    confirmLabel: AppStrings.reply,
    initialText: review.reply,
    requiredMessage: AppStrings.replyNeeded,
  );
  if (reply == null || !context.mounted) return false;
  final messenger = ScaffoldMessenger.of(context);
  try {
    await save(reply);
    messenger.showSnackBar(const SnackBar(content: Text(AppStrings.replySaved)));
    return true;
  } catch (e) {
    messenger.showSnackBar(SnackBar(content: Text(ErrorMessages.from(e))));
    return false;
  }
}
