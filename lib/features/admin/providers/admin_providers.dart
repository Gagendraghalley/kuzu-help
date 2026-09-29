import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_constants.dart';
import '../../../shared/models/profile.dart';
import '../../../shared/models/report.dart';
import '../../../shared/models/worker_listing.dart';
import '../../profile/providers/profile_providers.dart';
import '../data/admin_repository.dart';

// Riverpod providers: who is an admin, workers awaiting approval, their
// documents, the Users list and Reports.
// Screens watch these; these call the repositories in ../data/.

final isAdminProvider = Provider.autoDispose<bool>(
    (ref) => ref.watch(myProfileProvider).valueOrNull?.role == UserRole.admin);

/// Settings -> 'Workers awaiting approval'.
final pendingWorkersProvider = FutureProvider.autoDispose<List<WorkerListing>>(
    (ref) => ref.watch(adminRepositoryProvider).getPendingWorkers());

/// C3 'Admin check': the worker's CID and certificate.
final workerDocumentsProvider = FutureProvider.autoDispose.family<WorkerDocuments?, String>(
    (ref, workerId) => ref.watch(adminRepositoryProvider).getDocuments(workerId));

/// Settings -> Users: what's typed in the search box.
final userSearchProvider = StateProvider.autoDispose<String>((ref) => '');

final usersProvider = FutureProvider.autoDispose<List<Profile>>((ref) =>
    ref.watch(adminRepositoryProvider).getUsers(search: ref.watch(userSearchProvider)));

/// Settings -> Reports: which ReportStatus is shown. Open ones first.
final reportStatusFilterProvider = StateProvider.autoDispose<String>((ref) => ReportStatus.open);

final reportsProvider = FutureProvider.autoDispose<List<Report>>((ref) =>
    ref.watch(adminRepositoryProvider).getReports(status: ref.watch(reportStatusFilterProvider)));
