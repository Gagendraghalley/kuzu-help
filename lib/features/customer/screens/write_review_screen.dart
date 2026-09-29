import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/strings/app_strings.dart';
import '../../../core/utils/error_messages.dart';
import '../../../core/utils/text_utils.dart';
import '../../../shared/models/review.dart';
import '../../../shared/widgets/async_view.dart';
import '../../../shared/widgets/avatar_image.dart';
import '../../../shared/widgets/primary_button.dart';
import '../../../shared/widgets/star_rating.dart';
import '../data/review_repository.dart';
import '../providers/search_providers.dart';
import '../providers/worker_details_providers.dart';

/// C4 Write a review
/// Purpose: Build trust through honest feedback.
/// Backend: Saves to reviews (one per customer per worker; loads existing for editing).
/// Done when: The worker's average updates immediately.
class WriteReviewScreen extends ConsumerWidget {
  final String workerId;

  const WriteReviewScreen({super.key, required this.workerId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final existing = ref.watch(myReviewProvider(workerId));

    return Scaffold(
      appBar: AppBar(
        title: Text(existing.valueOrNull != null ? AppStrings.editReview : AppStrings.writeReview),
      ),
      body: SafeArea(
        child: AsyncView(
          value: existing,
          onRetry: () => ref.invalidate(myReviewProvider(workerId)),
          data: (review) => _ReviewForm(workerId: workerId, existing: review),
        ),
      ),
    );
  }
}

class _ReviewForm extends ConsumerStatefulWidget {
  final String workerId;
  final Review? existing;

  const _ReviewForm({required this.workerId, required this.existing});

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
          .read(reviewRepositoryProvider)
          .saveReview(workerId: widget.workerId, rating: _rating, comment: _comment.text.orNull);
      // The new average and review show straight away.
      ref.invalidate(workerDetailsProvider(widget.workerId));
      ref.invalidate(workerReviewsProvider(widget.workerId));
      ref.invalidate(myReviewProvider(widget.workerId));
      ref.invalidate(workerSearchProvider);
      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      context.pop();
      messenger.showSnackBar(const SnackBar(content: Text(AppStrings.reviewSaved)));
    } catch (e) {
      if (mounted) setState(() => _error = ErrorMessages.from(e));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final worker = ref.watch(workerDetailsProvider(widget.workerId)).valueOrNull?.worker;
    final text = Theme.of(context).textTheme;

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        if (worker != null) ...[
          Row(
            children: [
              AvatarImage(url: worker.avatarUrl, name: worker.fullName, size: 48),
              const SizedBox(width: 12),
              Expanded(
                child: Text(worker.fullName, style: text.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 28),
        ],
        Text(
          AppStrings.howWasTheWork,
          textAlign: TextAlign.center,
          style: text.titleLarge?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Center(
          child: StarRating(
            rating: _rating.toDouble(),
            size: 44,
            onChanged: (stars) => setState(() {
              _rating = stars;
              _error = null;
            }),
          ),
        ),
        SizedBox(
          height: 28,
          child: Text(
            AppStrings.ratingWord(_rating),
            textAlign: TextAlign.center,
            style: text.titleMedium?.copyWith(color: Theme.of(context).colorScheme.primary),
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _comment,
          minLines: 4,
          maxLines: 8,
          maxLength: 1000,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(
            labelText: AppStrings.reviewComment,
            hintText: AppStrings.reviewCommentHint,
            alignLabelWithHint: true,
          ),
        ),
        if (_error != null) ...[
          const SizedBox(height: 8),
          Semantics(
            liveRegion: true,
            child: Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ),
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
