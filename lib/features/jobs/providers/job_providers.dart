import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_constants.dart';
import '../../../shared/models/job_request.dart';
import '../../profile/providers/profile_providers.dart';
import '../data/job_repository.dart';

// Riverpod providers: the logged-in user's job requests and their photos.
// Screens watch these; these call the repositories in ../data/.

/// Workers: the requests sent to them. Customers (and admins): the ones they
/// sent. Invalidate after sending one or changing its status.
final myJobsProvider = FutureProvider.autoDispose<List<JobRequest>>((ref) async {
  final repo = ref.watch(jobRepositoryProvider);
  final profile = await ref.watch(myProfileProvider.future);
  return repo.getMyJobs(asWorker: profile?.role == UserRole.worker);
});

/// B5: requests waiting for the worker's answer.
final newJobCountProvider = Provider.autoDispose<int>((ref) =>
    ref.watch(myJobsProvider).valueOrNull?.where((j) => j.status == JobStatus.pending).length ?? 0);

/// C3: the customer's open request to this worker, if any (only one allowed).
final openJobWithProvider = Provider.autoDispose.family<JobRequest?, String>((ref, workerId) =>
    ref.watch(myJobsProvider).valueOrNull?.where((j) => j.workerId == workerId && j.isOpen).firstOrNull);

final jobPhotoUrlProvider = FutureProvider.autoDispose.family<String, String>(
    (ref, path) => ref.watch(jobRepositoryProvider).photoUrl(path));
