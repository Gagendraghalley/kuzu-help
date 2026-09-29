import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/models/profile.dart';
import '../../../shared/models/service_category.dart';
import '../../../shared/models/verification.dart';
import '../../../shared/models/work_photo.dart';
import '../../../shared/models/worker_profile.dart';
import '../../../shared/models/worker_service.dart';
import '../../customer/providers/search_providers.dart';
import '../../profile/providers/profile_providers.dart';
import '../data/work_photo_repository.dart';
import '../data/worker_repository.dart';

// Riverpod providers: Worker's own profile, verification status and setup progress.
// Screens watch these; these call the repositories in ../data/.

/// B1, B4: the worker's own worker_profiles row (null before B1 is saved).
final myWorkerProfileProvider = FutureProvider.autoDispose<WorkerProfile?>(
    (ref) => ref.watch(workerRepositoryProvider).getMyWorkerProfile());

/// B2: the services the worker offers now.
final myServicesProvider = FutureProvider.autoDispose<List<WorkerService>>(
    (ref) => ref.watch(workerRepositoryProvider).getMyServices());

/// B3: the documents already sent, if any.
final myVerificationProvider = FutureProvider.autoDispose<Verification?>(
    (ref) => ref.watch(workerRepositoryProvider).getMyVerification());

/// B1: what the form starts with.
final workerProfileFormProvider = FutureProvider.autoDispose<(Profile?, WorkerProfile?)>(
    (ref) => (ref.watch(myProfileProvider.future), ref.watch(myWorkerProfileProvider.future)).wait);

/// Photos of a worker's past work: on their page (C3) and their photos screen.
final workPhotosProvider = FutureProvider.autoDispose.family<List<WorkPhoto>, String>(
    (ref, workerId) => ref.watch(workPhotoRepositoryProvider).getPhotos(workerId));

/// B2: every category, and the ones the worker already offers.
final servicesFormProvider = FutureProvider.autoDispose<(List<ServiceCategory>, List<WorkerService>)>(
    (ref) => (ref.watch(categoriesProvider.future), ref.watch(myServicesProvider.future)).wait);
