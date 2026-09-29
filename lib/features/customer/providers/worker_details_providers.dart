import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/models/review.dart';
import '../../../shared/models/worker_listing.dart';
import '../data/contact_repository.dart';
import '../data/directory_repository.dart';
import '../data/review_repository.dart';
import '../data/saved_workers_repository.dart';

// Riverpod providers: one worker's listing, services and reviews (C3, C4, B5),
// whether the customer may review them, and saved workers.
// Screens watch these; these call the repositories in ../data/.

/// C3, and B5 for the worker's own listing. Null when not listed.
final workerDetailsProvider = FutureProvider.autoDispose.family<WorkerDetails?, String>(
    (ref, workerId) => ref.watch(directoryRepositoryProvider).getWorker(workerId));

final workerReviewsProvider = FutureProvider.autoDispose.family<List<Review>, String>(
    (ref, workerId) => ref.watch(reviewRepositoryProvider).getReviews(workerId));

/// C4: the customer's own review of a worker, to edit.
final myReviewProvider = FutureProvider.autoDispose.family<Review?, String>(
    (ref, workerId) => ref.watch(reviewRepositoryProvider).getMyReview(workerId));

/// C4: whether the customer has called, messaged or sent a job request to the
/// worker; only then can they review them. Invalidate after getting in touch.
final hasContactedProvider = FutureProvider.autoDispose.family<bool, String>(
    (ref, workerId) => ref.watch(contactRepositoryProvider).hasContacted(workerId));

/// C3: the heart. Invalidate (with savedWorkersProvider) after changing it.
final isSavedProvider = FutureProvider.autoDispose.family<bool, String>(
    (ref, workerId) => ref.watch(savedWorkersRepositoryProvider).isSaved(workerId));

/// C1 -> Saved workers.
final savedWorkersProvider = FutureProvider.autoDispose<List<WorkerListing>>(
    (ref) => ref.watch(savedWorkersRepositoryProvider).getSavedWorkers());
