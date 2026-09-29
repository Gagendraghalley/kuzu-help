import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/models/review.dart';
import '../data/directory_repository.dart';
import '../data/review_repository.dart';

// Riverpod providers: one worker's listing, services and reviews (C3, C4, B5).
// Screens watch these; these call the repositories in ../data/.

/// C3, and B5 for the worker's own listing. Null when not listed.
final workerDetailsProvider = FutureProvider.autoDispose.family<WorkerDetails?, String>(
    (ref, workerId) => ref.watch(directoryRepositoryProvider).getWorker(workerId));

final workerReviewsProvider = FutureProvider.autoDispose.family<List<Review>, String>(
    (ref, workerId) => ref.watch(reviewRepositoryProvider).getReviews(workerId));

/// C4: the customer's own review of a worker, to edit.
final myReviewProvider = FutureProvider.autoDispose.family<Review?, String>(
    (ref, workerId) => ref.watch(reviewRepositoryProvider).getMyReview(workerId));
