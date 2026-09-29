import '../../shared/models/profile.dart';
import '../../shared/models/worker_progress.dart';
import '../constants/app_constants.dart';
import 'route_names.dart';

/// A1: the first screen for a user when the app opens or they log in.
/// [profile] is null when nobody is logged in; [worker] is only needed for workers.
String startRouteFor(Profile? profile, {WorkerProgress? worker}) {
  if (profile == null) return Routes.welcome;
  // Customers, and admins (they use the app as a customer).
  if (profile.role != UserRole.worker) return Routes.customerHome;

  final progress = worker ?? WorkerProgress.notStarted;
  if (!progress.hasProfile) return Routes.workerSetup;
  if (progress.status == VerificationStatus.approved) return Routes.workerDashboard;
  if (!progress.hasServices) return Routes.workerServices;
  if (!progress.hasVerification) return Routes.workerVerification;
  return Routes.workerPending; // pending, or rejected with the admin's note
}
