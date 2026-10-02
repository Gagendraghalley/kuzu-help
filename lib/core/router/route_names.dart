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
  static const workPhotos = '/worker/photos';

  // Customer (Part C)
  static const customerHome = '/home';
  static const workerList = '/home/workers';
  static const workerDetails = '/home/worker/:id';
  static const writeReview = '/home/worker/:id/review';
  static const reportWorker = '/home/worker/:id/report';
  static const requestJob = '/home/worker/:id/request';
  static const searchWorkers = '/home/search';
  static const savedWorkers = '/home/saved';

  static String workerDetailsFor(String id) => '/home/worker/$id';
  static String writeReviewFor(String id) => '/home/worker/$id/review';
  static String reportWorkerFor(String id) => '/home/worker/$id/report';
  static String requestJobFor(String id) => '/home/worker/$id/request';

  // Job requests: sent (customers) or received (workers)
  static const jobs = '/jobs';

  // Sports grounds: customers (Customer Home switches to them; workers open /grounds)
  static const grounds = '/grounds';
  static const myBookings = '/grounds/bookings';
  static const searchGrounds = '/grounds/search';
  static const venueDetails = '/grounds/venue/:id';
  static const bookGround = '/grounds/venue/:id/book/:groundId';
  static const writeVenueReview = '/grounds/venue/:id/review';

  static String venueDetailsFor(String id) => '/grounds/venue/$id';
  static String bookGroundFor(String venueId, String groundId) => '/grounds/venue/$venueId/book/$groundId';
  static String writeVenueReviewFor(String id) => '/grounds/venue/$id/review';

  // Sports grounds: running a venue. A venue manager's home is theirs;
  // admins add venues (Settings -> Sports venues) and run any.
  static const managerHome = '/manager';
  static const playerHome = '/play'; // players: sports grounds and their bookings
  static const addVenue = '/venues/new';
  static const venueManage = '/venues/:id';
  static const editVenue = '/venues/:id/edit';
  static const venueBookings = '/venues/:id/bookings';
  static const venueTimings = '/venues/:id/timings';
  static const venueRecords = '/venues/:id/records';
  static const venueSubscription = '/venues/:id/subscription'; // the manager reads it; admins change it

  static String venueManageFor(String id) => '/venues/$id';
  static String editVenueFor(String id) => '/venues/$id/edit';
  static String venueBookingsFor(String id) => '/venues/$id/bookings';
  static String venueTimingsFor(String venueId) => '/venues/$venueId/timings';
  static String venueRecordsFor(String venueId) => '/venues/$venueId/records';
  static String venueSubscriptionFor(String venueId) => '/venues/$venueId/subscription';

  // Shared (Part D)
  static const settings = '/settings';
  static const editProfile = '/settings/edit';
  static const notifications = '/notifications';

  // Admin (Phase 5)
  static const pendingWorkers = '/admin/pending';
  static const users = '/admin/users';
  static const reports = '/admin/reports';
  static const adminVenues = '/admin/venues';
  static const adminBilling = '/admin/billing'; // every ground's subscription and billing
}
