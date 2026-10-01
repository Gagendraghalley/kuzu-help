import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show PostgrestException;

import '../../../core/strings/app_strings.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/error_messages.dart';
import '../../../core/utils/text_utils.dart';
import '../../../shared/models/venue_review.dart';
import '../../../shared/widgets/async_view.dart';
import '../../../shared/widgets/form_error.dart';
import '../../../shared/widgets/primary_button.dart';
import '../../../shared/widgets/star_rating.dart';
import '../data/venue_repository.dart';
import '../providers/venue_providers.dart';

/// Review a venue
/// Purpose: Tell other teams how the ground was.
/// Backend: Saves to venue_reviews: one per customer per venue, only once
/// they have played there (loads their review for editing).
/// Done when: The venue's rating updates straight away, and its manager is told.
class WriteVenueReviewScreen extends ConsumerWidget {
  final String venueId;

  const WriteVenueReviewScreen({super.key, required this.venueId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final existing = ref.watch(myVenueReviewProvider(venueId));

    return Scaffold(
      appBar: AppBar(
        title: Text(existing.valueOrNull != null ? AppStrings.editReview : AppStrings.writeReview),
      ),
      body: SafeArea(
        child: AsyncView(
          value: existing,
          onRetry: () => ref.invalidate(myVenueReviewProvider(venueId)),
          data: (review) => _ReviewForm(venueId: venueId, existing: review),
        ),
      ),
    );
  }
}

class _ReviewForm extends ConsumerStatefulWidget {
  final String venueId;
  final VenueReview? existing;

  const _ReviewForm({required this.venueId, required this.existing});

  @override
  ConsumerState<_ReviewForm> createState() => _ReviewFormState();
}

class _ReviewFormState extends ConsumerState<_ReviewForm> {
  late int _rating = widget.existing?.rating ?? 0;
  late final _comment = TextEditingController(text: widget.existing?.comment);
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _comment.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) return;
    if (_rating == 0) {
      setState(() => _error = AppStrings.chooseRating);
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref
          .read(venueRepositoryProvider)
          .saveReview(venueId: widget.venueId, rating: _rating, comment: _comment.text.orNull);
      // The new average and review show straight away.
      ref.invalidate(venueDetailsProvider(widget.venueId));
      ref.invalidate(venueReviewsProvider(widget.venueId));
      ref.invalidate(myVenueReviewProvider(widget.venueId));
      ref.invalidate(venuesProvider);
      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      context.pop();
      messenger.showSnackBar(const SnackBar(content: Text(AppStrings.reviewSaved)));
    } catch (e) {
      if (mounted) {
        setState(() => _error = switch (e) {
              PostgrestException(code: '42501') => AppStrings.reviewVenueAfterPlaying,
              _ => ErrorMessages.from(e),
            });
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final venue = ref.watch(venueDetailsProvider(widget.venueId)).valueOrNull?.venue;
    final text = Theme.of(context).textTheme;

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        if (venue != null) ...[
          Text(venue.name, textAlign: TextAlign.center, style: text.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 16),
        ],
        Card(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 24, 12, 16),
            child: Column(
              children: [
                Text(
                  AppStrings.howWasTheGround,
                  textAlign: TextAlign.center,
                  style: text.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 8),
                StarRating(
                  rating: _rating.toDouble(),
                  size: 44,
                  onChanged: (stars) => setState(() {
                    _rating = stars;
                    _error = null;
                  }),
                ),
                SizedBox(
                  height: 28,
                  child: Text(
                    AppStrings.ratingWord(_rating),
                    textAlign: TextAlign.center,
                    style: text.titleMedium?.copyWith(color: AppColors.primaryDeep),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
        TextField(
          controller: _comment,
          minLines: 4,
          maxLines: 8,
          maxLength: 1000,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(
            labelText: AppStrings.reviewComment,
            hintText: AppStrings.venueReviewCommentHint,
            alignLabelWithHint: true,
          ),
        ),
        if (_error != null) ...[
          const SizedBox(height: 8),
          FormError(_error!),
        ],
        const SizedBox(height: 24),
        PrimaryButton(
          label: widget.existing != null ? AppStrings.updateReview : AppStrings.postReview,
          isLoading: _saving,
          onPressed: _save,
        ),
      ],
    );
  }
}
