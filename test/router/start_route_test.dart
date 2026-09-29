import 'package:bhutan_services/core/constants/app_constants.dart';
import 'package:bhutan_services/core/router/route_names.dart';
import 'package:bhutan_services/core/router/start_route.dart';
import 'package:bhutan_services/shared/models/profile.dart';
import 'package:bhutan_services/shared/models/worker_progress.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Profile profile(String role) => Profile(id: 'user-1', fullName: 'Test', role: role);

  test('logged-out users go to Welcome', () {
    expect(startRouteFor(null), Routes.welcome);
  });

  test('customers and admins go to Customer Home', () {
    expect(startRouteFor(profile(UserRole.customer)), Routes.customerHome);
    expect(startRouteFor(profile(UserRole.admin)), Routes.customerHome);
  });

  test('workers continue setup where they stopped', () {
    final worker = profile(UserRole.worker);
    expect(startRouteFor(worker, worker: WorkerProgress.notStarted), Routes.workerSetup);
    expect(
      startRouteFor(worker,
          worker: const WorkerProgress(hasProfile: true, status: VerificationStatus.pending)),
      Routes.workerServices,
    );
    expect(
      startRouteFor(worker,
          worker: const WorkerProgress(
              hasProfile: true, hasServices: true, status: VerificationStatus.pending)),
      Routes.workerVerification,
    );
  });

  test('workers who sent their CID wait on the pending screen, even if rejected', () {
    final worker = profile(UserRole.worker);
    for (final status in [VerificationStatus.pending, VerificationStatus.rejected]) {
      expect(
        startRouteFor(worker,
            worker: WorkerProgress(
                hasProfile: true, hasServices: true, hasVerification: true, status: status)),
        Routes.workerPending,
      );
    }
  });

  test('approved workers go to their dashboard', () {
    expect(
      startRouteFor(profile(UserRole.worker),
          worker: const WorkerProgress(hasProfile: true, status: VerificationStatus.approved)),
      Routes.workerDashboard,
    );
  });
}
