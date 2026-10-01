import '../../shared/models/profile.dart';
import '../../shared/models/worker_progress.dart';
import '../constants/app_constants.dart';
import 'route_names.dart';

/// Where users who have finished setting up start: nothing is waiting for them.
const homeRoutes = {Routes.customerHome, Routes.workerDashboard, Routes.managerHome, Routes.playerHome};

/// A1: the first screen for a user when the app opens or they log in.
/// [profile] is null when nobody is logged in; [worker] is only needed for workers.
String startRouteFor(Profile? profile, {WorkerProgress? worker}) {
  if (profile == null) return Routes.welcome;
  // The person who runs a sports venue: their venue.
  if (profile.role == UserRole.groundManager) return Routes.managerHome;
  // Players only book grounds. (One who adds home services becomes a
  // customer, whose home has sports grounds too.)
  if (profile.role == UserRole.player) return Routes.playerHome;
  // Customers, and admins (they use the app as a customer).
  if (profile.role != UserRole.worker) return Routes.customerHome;

  final progress = worker ?? WorkerProgress.notStarted;
  if (!progress.hasProfile) return Routes.workerSetup;
  if (progress.status == VerificationStatus.approved) return Routes.workerDashboard;
  if (!progress.hasServices) return Routes.workerServices;
  if (!progress.hasVerification) return Routes.workerVerification;
  return Routes.workerPending; // pending, or rejected with the admin's note
}
