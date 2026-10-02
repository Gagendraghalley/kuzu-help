import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/admin/screens/pending_workers_screen.dart';
import '../../features/admin/screens/reports_screen.dart';
import '../../features/admin/screens/users_screen.dart';
import '../../features/admin/screens/venues_screen.dart';
import '../../features/auth/data/auth_repository.dart';
import '../../features/auth/screens/deactivated_screen.dart';
import '../../features/auth/screens/login_screen.dart';
import '../../features/auth/screens/set_password_screen.dart';
import '../../features/auth/screens/splash_screen.dart';
import '../../features/auth/screens/verify_otp_screen.dart';
import '../../features/auth/screens/welcome_screen.dart';
import '../../features/customer/screens/customer_home_screen.dart';
import '../../features/customer/screens/report_worker_screen.dart';
import '../../features/customer/screens/saved_workers_screen.dart';
import '../../features/customer/screens/search_workers_screen.dart';
import '../../features/customer/screens/worker_details_screen.dart';
import '../../features/customer/screens/worker_list_screen.dart';
import '../../features/customer/screens/write_review_screen.dart';
import '../../features/grounds/screens/book_ground_screen.dart';
import '../../features/grounds/screens/booking_records_screen.dart';
import '../../features/grounds/screens/ground_timings_screen.dart';
import '../../features/grounds/screens/my_bookings_screen.dart';
import '../../features/grounds/screens/player_home_screen.dart';
import '../../features/grounds/screens/manager_home_screen.dart';
import '../../features/grounds/screens/search_venues_screen.dart';
import '../../features/grounds/screens/subscription_screen.dart';
import '../../features/grounds/screens/venue_bookings_screen.dart';
import '../../features/grounds/screens/venue_details_screen.dart';
import '../../features/grounds/screens/venue_form_screen.dart';
import '../../features/grounds/screens/venue_list_screen.dart';
import '../../features/grounds/screens/venue_manage_screen.dart';
import '../../features/grounds/screens/write_venue_review_screen.dart';
import '../../features/jobs/screens/job_request_screen.dart';
import '../../features/jobs/screens/jobs_screen.dart';
import '../../features/notifications/screens/notifications_screen.dart';
import '../../features/profile/screens/edit_profile_screen.dart';
import '../../features/profile/screens/settings_screen.dart';
import '../../features/worker/screens/pending_approval_screen.dart';
import '../../features/worker/screens/profile_setup_screen.dart';
import '../../features/worker/screens/services_prices_screen.dart';
import '../../features/worker/screens/verification_upload_screen.dart';
import '../../features/worker/screens/work_photos_screen.dart';
import '../../features/worker/screens/worker_dashboard_screen.dart';
import 'route_names.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  final auth = ref.watch(authRepositoryProvider);
  final authChanges = _StreamListenable(auth.authChanges);
  ref.onDispose(authChanges.dispose);

  return GoRouter(
    initialLocation: Routes.splash,
    refreshListenable: authChanges, // re-check the redirect on every log in / log out
    // fullPath is the route's pattern ('/grounds/venue/:id'), so a venue's page matches _publicRoutes.
    redirect: (context, state) => _redirect(auth.isLoggedIn, state.fullPath ?? state.matchedLocation),
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
      GoRoute(path: Routes.workPhotos, builder: (_, __) => const WorkPhotosScreen()),

      GoRoute(path: Routes.customerHome, builder: (_, __) => const CustomerHomeScreen()),
      GoRoute(path: Routes.workerList, builder: (_, __) => const WorkerListScreen()),
      GoRoute(path: Routes.searchWorkers, builder: (_, __) => const SearchWorkersScreen()),
      GoRoute(path: Routes.savedWorkers, builder: (_, __) => const SavedWorkersScreen()),
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
      GoRoute(
        path: Routes.requestJob,
        builder: (_, s) => JobRequestScreen(workerId: s.pathParameters['id']!),
      ),
      GoRoute(path: Routes.jobs, builder: (_, __) => const JobsScreen()),

      GoRoute(path: Routes.grounds, builder: (_, __) => const VenueListScreen()),
      GoRoute(path: Routes.myBookings, builder: (_, __) => const MyBookingsScreen()),
      GoRoute(path: Routes.searchGrounds, builder: (_, __) => const SearchVenuesScreen()),
      GoRoute(
        path: Routes.venueDetails,
        builder: (_, s) => VenueDetailsScreen(venueId: s.pathParameters['id']!),
      ),
      GoRoute(
        path: Routes.bookGround,
        builder: (_, s) => BookGroundScreen(venueId: s.pathParameters['id']!, groundId: s.pathParameters['groundId']!),
      ),
      GoRoute(
        path: Routes.writeVenueReview,
        builder: (_, s) => WriteVenueReviewScreen(venueId: s.pathParameters['id']!),
      ),
      GoRoute(path: Routes.managerHome, builder: (_, __) => const ManagerHomeScreen()),
      GoRoute(path: Routes.playerHome, builder: (_, __) => const PlayerHomeScreen()),
      // Before venueManage, or 'new' would be taken for a venue's ID.
      GoRoute(path: Routes.addVenue, builder: (_, __) => const VenueFormScreen()),
      GoRoute(
        path: Routes.venueManage,
        builder: (_, s) => VenueManageScreen(venueId: s.pathParameters['id']!),
      ),
      GoRoute(
        path: Routes.editVenue,
        builder: (_, s) => VenueFormScreen(venueId: s.pathParameters['id']!),
      ),
      GoRoute(
        path: Routes.venueBookings,
        builder: (_, s) => VenueBookingsScreen(venueId: s.pathParameters['id']!),
      ),
      GoRoute(
        path: Routes.venueTimings,
        builder: (_, s) => GroundTimingsScreen(venueId: s.pathParameters['id']!),
      ),
      GoRoute(
        path: Routes.venueRecords,
        builder: (_, s) => BookingRecordsScreen(venueId: s.pathParameters['id']!),
      ),
      GoRoute(
        path: Routes.venueSubscription,
        builder: (_, s) => SubscriptionScreen(venueId: s.pathParameters['id']!),
      ),

      GoRoute(path: Routes.settings, builder: (_, __) => const SettingsScreen()),
      GoRoute(path: Routes.editProfile, builder: (_, __) => const EditProfileScreen()),
      GoRoute(path: Routes.notifications, builder: (_, __) => const NotificationsScreen()),

      GoRoute(path: Routes.pendingWorkers, builder: (_, __) => const PendingWorkersScreen()),
      GoRoute(path: Routes.users, builder: (_, __) => const UsersScreen()),
      GoRoute(path: Routes.reports, builder: (_, __) => const ReportsScreen()),
      GoRoute(path: Routes.adminVenues, builder: (_, __) => const AdminVenuesScreen()),
    ],
  );
});

const _loggedOutRoutes = {Routes.welcome, Routes.login, Routes.verifyOtp};

/// Sports grounds, for everyone: logged-out visitors look at and search
/// venues and their free times, then log in to book.
const _publicRoutes = {Routes.grounds, Routes.searchGrounds, Routes.venueDetails, Routes.bookGround};

/// The splash screen (A1) picks each user's first screen itself (A5 set
/// password comes first when needed). Logged-out users see Welcome, login and
/// sports grounds; logging in goes back to the splash.
String? _redirect(bool loggedIn, String location) {
  if (location == Routes.splash || _publicRoutes.contains(location)) return null;
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
