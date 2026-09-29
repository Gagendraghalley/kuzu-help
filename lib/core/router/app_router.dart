import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/admin/screens/pending_workers_screen.dart';
import '../../features/admin/screens/users_screen.dart';
import '../../features/auth/data/auth_repository.dart';
import '../../features/auth/screens/deactivated_screen.dart';
import '../../features/auth/screens/login_screen.dart';
import '../../features/auth/screens/set_password_screen.dart';
import '../../features/auth/screens/splash_screen.dart';
import '../../features/auth/screens/verify_otp_screen.dart';
import '../../features/auth/screens/welcome_screen.dart';
import '../../features/customer/screens/customer_home_screen.dart';
import '../../features/customer/screens/report_worker_screen.dart';
import '../../features/customer/screens/worker_details_screen.dart';
import '../../features/customer/screens/worker_list_screen.dart';
import '../../features/customer/screens/write_review_screen.dart';
import '../../features/profile/screens/edit_profile_screen.dart';
import '../../features/profile/screens/settings_screen.dart';
import '../../features/worker/screens/pending_approval_screen.dart';
import '../../features/worker/screens/profile_setup_screen.dart';
import '../../features/worker/screens/services_prices_screen.dart';
import '../../features/worker/screens/verification_upload_screen.dart';
import '../../features/worker/screens/worker_dashboard_screen.dart';
import 'route_names.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  final auth = ref.watch(authRepositoryProvider);
  final authChanges = _StreamListenable(auth.authChanges);
  ref.onDispose(authChanges.dispose);

  return GoRouter(
    initialLocation: Routes.splash,
    refreshListenable: authChanges, // re-check the redirect on every log in / log out
    redirect: (context, state) => _redirect(auth.isLoggedIn, state.matchedLocation),
    routes: [
      GoRoute(path: Routes.splash, builder: (_, __) => const SplashScreen()),
      GoRoute(path: Routes.welcome, builder: (_, __) => const WelcomeScreen()),
      GoRoute(path: Routes.login, builder: (_, __) => const LoginScreen()),
      GoRoute(path: Routes.verifyOtp, builder: (_, __) => const VerifyOtpScreen()),
      GoRoute(path: Routes.setPassword, builder: (_, __) => const SetPasswordScreen()),
      GoRoute(path: Routes.deactivated, builder: (_, __) => const DeactivatedScreen()),

      GoRoute(path: Routes.workerSetup, builder: (_, __) => const ProfileSetupScreen()),
      GoRoute(path: Routes.workerServices, builder: (_, __) => const ServicesPricesScreen()),
      GoRoute(path: Routes.workerVerification, builder: (_, __) => const VerificationUploadScreen()),
      GoRoute(path: Routes.workerPending, builder: (_, __) => const PendingApprovalScreen()),
      GoRoute(path: Routes.workerDashboard, builder: (_, __) => const WorkerDashboardScreen()),

      GoRoute(path: Routes.customerHome, builder: (_, __) => const CustomerHomeScreen()),
      GoRoute(path: Routes.workerList, builder: (_, __) => const WorkerListScreen()),
      GoRoute(
        path: Routes.workerDetails,
        builder: (_, s) => WorkerDetailsScreen(workerId: s.pathParameters['id']!),
      ),
      GoRoute(
        path: Routes.writeReview,
        builder: (_, s) => WriteReviewScreen(workerId: s.pathParameters['id']!),
      ),
      GoRoute(
        path: Routes.reportWorker,
        builder: (_, s) => ReportWorkerScreen(workerId: s.pathParameters['id']!),
      ),

      GoRoute(path: Routes.settings, builder: (_, __) => const SettingsScreen()),
      GoRoute(path: Routes.editProfile, builder: (_, __) => const EditProfileScreen()),

      GoRoute(path: Routes.pendingWorkers, builder: (_, __) => const PendingWorkersScreen()),
      GoRoute(path: Routes.users, builder: (_, __) => const UsersScreen()),
    ],
  );
});

const _loggedOutRoutes = {Routes.welcome, Routes.login, Routes.verifyOtp};

/// The splash screen (A1) picks each user's first screen itself (A5 set
/// password comes first when needed). Logged-out users only see Welcome and
/// login; logging in goes back to the splash.
String? _redirect(bool loggedIn, String location) {
  if (location == Routes.splash) return null;
  if (!loggedIn) return _loggedOutRoutes.contains(location) ? null : Routes.welcome;
  if (_loggedOutRoutes.contains(location)) return Routes.splash;
  return null;
}

/// Lets GoRouter listen to a stream.
class _StreamListenable extends ChangeNotifier {
  _StreamListenable(Stream<void> stream) {
    _subscription = stream.listen((_) => notifyListeners());
  }

  late final StreamSubscription<void> _subscription;

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}
