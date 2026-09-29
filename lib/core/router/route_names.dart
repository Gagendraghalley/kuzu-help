class Routes {
  // Auth (Part A)
  static const splash = '/';
  static const welcome = '/welcome';
  static const login = '/login';
  static const verifyOtp = '/verify';
  static const setPassword = '/set-password';
  static const deactivated = '/deactivated';

  // Worker (Part B)
  static const workerSetup = '/worker/setup';
  static const workerServices = '/worker/services';
  static const workerVerification = '/worker/verification';
  static const workerPending = '/worker/pending';
  static const workerDashboard = '/worker';

  // Customer (Part C)
  static const customerHome = '/home';
  static const workerList = '/home/workers';
  static const workerDetails = '/home/worker/:id';
  static const writeReview = '/home/worker/:id/review';
  static const reportWorker = '/home/worker/:id/report';

  static String workerDetailsFor(String id) => '/home/worker/$id';
  static String writeReviewFor(String id) => '/home/worker/$id/review';
  static String reportWorkerFor(String id) => '/home/worker/$id/report';

  // Shared (Part D)
  static const settings = '/settings';
  static const editProfile = '/settings/edit';
  static const notifications = '/notifications';

  // Admin (Phase 5)
  static const pendingWorkers = '/admin/pending';
  static const users = '/admin/users';
}
