import 'dart:async';
import 'dart:typed_data';

import 'package:bhutan_services/app.dart';
import 'package:bhutan_services/core/constants/app_constants.dart';
import 'package:bhutan_services/core/location/location_service.dart';
import 'package:bhutan_services/core/location/my_position.dart';
import 'package:bhutan_services/core/utils/geo_utils.dart';
import 'package:bhutan_services/features/admin/data/admin_repository.dart';
import 'package:bhutan_services/features/auth/data/auth_repository.dart';
import 'package:bhutan_services/features/customer/data/contact_repository.dart';
import 'package:bhutan_services/features/customer/data/directory_repository.dart';
import 'package:bhutan_services/features/customer/data/report_repository.dart';
import 'package:bhutan_services/features/customer/data/review_repository.dart';
import 'package:bhutan_services/features/customer/data/saved_workers_repository.dart';
import 'package:bhutan_services/features/grounds/data/booking_repository.dart';
import 'package:bhutan_services/features/grounds/data/venue_repository.dart';
import 'package:bhutan_services/features/jobs/data/job_repository.dart';
import 'package:bhutan_services/features/notifications/data/notification_repository.dart';
import 'package:bhutan_services/features/notifications/data/push_repository.dart';
import 'package:bhutan_services/features/profile/data/profile_repository.dart';
import 'package:bhutan_services/features/worker/data/work_photo_repository.dart';
import 'package:bhutan_services/features/worker/data/worker_repository.dart';
import 'package:bhutan_services/core/utils/bhutan_time.dart';
import 'package:bhutan_services/shared/models/app_notification.dart';
import 'package:bhutan_services/shared/models/ground.dart';
import 'package:bhutan_services/shared/models/ground_booking.dart';
import 'package:bhutan_services/shared/models/job_request.dart';
import 'package:bhutan_services/shared/models/profile.dart';
import 'package:bhutan_services/shared/models/regular_booking.dart';
import 'package:bhutan_services/shared/models/report.dart';
import 'package:bhutan_services/shared/models/review.dart';
import 'package:bhutan_services/shared/models/service_category.dart';
import 'package:bhutan_services/shared/models/venue.dart';
import 'package:bhutan_services/shared/models/venue_review.dart';
import 'package:bhutan_services/shared/models/verification.dart';
import 'package:bhutan_services/shared/models/work_photo.dart';
import 'package:bhutan_services/shared/models/worker_listing.dart';
import 'package:bhutan_services/shared/models/worker_profile.dart';
import 'package:bhutan_services/shared/models/worker_progress.dart';
import 'package:bhutan_services/shared/models/worker_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show AuthException, PostgrestException;

// The whole app with Supabase replaced by in-memory fakes.

/// The logged-in user's ID in every test.
const me = 'user-1';

typedef SentCode = ({String email, String? fullName, String? role});

/// Any code except 000000 logs in; so does [correctPassword]. Only
/// [registeredEmail] has an account already.
class FakeAuthRepository implements AuthRepository {
  FakeAuthRepository({bool loggedIn = false, this.hasPassword = false}) : _loggedIn = loggedIn;

  static const correctPassword = 'druk-2026';
  static const registeredEmail = 'dorji@example.com';

  final _changes = StreamController<void>.broadcast();
  final sentCodes = <SentCode>[];
  final passwordLogIns = <String>[]; // the emails used
  String? savedPassword;
  bool _loggedIn;

  @override
  bool get isLoggedIn => _loggedIn;

  @override
  String? get userId => _loggedIn ? me : null;

  @override
  bool hasPassword;

  @override
  Stream<void> get authChanges => _changes.stream;

  @override
  Future<void> sendOtp({required String email, String? fullName, String? role}) async {
    sentCodes.add((email: email, fullName: fullName, role: role));
  }

  @override
  Future<void> verifyOtp({required String email, required String code}) async {
    if (code == '000000') {
      throw const AuthException('Token has expired or is invalid', code: 'otp_expired');
    }
    _loggedIn = true;
    _changes.add(null);
  }

  @override
  Future<bool> isEmailRegistered(String email) async => email == registeredEmail;

  /// config/dev.json has the Google client IDs, so the button shows.
  @override
  bool canUseGoogle = true;

  @override
  bool usesGoogle = false;

  /// False: the user closes Google's account picker instead of picking one.
  bool googlePicksAccount = true;
  int googleSignIns = 0;

  @override
  Future<bool> signInWithGoogle() async {
    googleSignIns++;
    if (!googlePicksAccount) return false;
    _loggedIn = true;
    usesGoogle = true;
    _changes.add(null);
    return true;
  }

  @override
  Future<void> signInWithPassword({required String email, required String password}) async {
    passwordLogIns.add(email);
    if (email != registeredEmail || password != correctPassword) {
      throw const AuthException('Invalid login credentials',
          statusCode: '400', code: 'invalid_credentials');
    }
    _loggedIn = true;
    _changes.add(null);
  }

  /// Like the real one, authChanges doesn't fire: the user stays logged in.
  @override
  Future<void> setPassword(String password) async {
    savedPassword = password;
    hasPassword = true;
  }

  @override
  Future<void> signOut() async {
    _loggedIn = false;
    _changes.add(null);
  }
}

class FakeProfileRepository implements ProfileRepository {
  FakeProfileRepository(this.profile);

  Profile profile;
  Uint8List? lastPhoto;
  bool deleted = false;

  @override
  Future<Profile?> getMyProfile() async => profile;

  @override
  Future<void> deleteAccount() async => deleted = true;

  @override
  Future<void> ensureMyProfile() async {} // the fake user always has one

  @override
  Future<void> updateProfile({
    required String fullName,
    String? dzongkhag,
    String? town,
    Uint8List? photo,
  }) async {
    lastPhoto = photo;
    profile = Profile(
      id: profile.id,
      fullName: fullName,
      role: profile.role,
      roles: profile.roles,
      email: profile.email,
      avatarUrl: profile.avatarUrl,
      dzongkhag: dzongkhag,
      town: town,
    );
  }

  // Like the database, these only change a customer or a worker; never an admin.
  @override
  Future<void> becomeWorker() async => _switch(from: UserRole.customer, to: UserRole.worker);

  @override
  Future<void> becomeCustomer() async => _switch(from: UserRole.worker, to: UserRole.customer);

  void _switch({required String from, required String to}) {
    if (profile.role != from) return;
    profile = _with(role: to);
  }

  /// The account was made just now (by a Google sign-in), for claimSignUpRole.
  bool isNewAccount = false;
  final claimedRoles = <String>[];

  /// Like claim_signup_role: only a new account that is just a customer
  /// takes the role, and then has only that one.
  @override
  Future<void> claimSignUpRole(String role) async {
    claimedRoles.add(role);
    if (!isNewAccount || profile.role != UserRole.customer || profile.roles.any((r) => r != UserRole.customer)) {
      return;
    }
    profile = Profile(
      id: profile.id,
      fullName: profile.fullName,
      role: role,
      roles: [role],
      email: profile.email,
      isActive: profile.isActive,
    );
  }

  final addedRoles = <String>[];

  /// Like add_my_role: the account keeps its roles and gains [role]; a
  /// player who adds home services becomes a customer.
  @override
  Future<void> addRole(String role) async {
    addedRoles.add(role);
    profile = _with(
      role: role == UserRole.customer && profile.role == UserRole.player ? UserRole.customer : profile.role,
      roles: {...profile.roles, role},
    );
  }

  /// [profile] with another main role, keeping (like the database) the
  /// customer and player roles it had.
  Profile _with({required String role, Iterable<String> roles = const []}) => Profile(
        id: profile.id,
        fullName: profile.fullName,
        role: role,
        roles: {role, ...profile.roles, ...roles}
            .where((r) => r == role || UserRole.addable.contains(r))
            .toList(),
        email: profile.email,
        phone: profile.phone,
        avatarUrl: profile.avatarUrl,
        dzongkhag: profile.dzongkhag,
        town: profile.town,
        isActive: profile.isActive,
        deactivatedReason: profile.deactivatedReason,
      );
}

class FakeWorkerRepository implements WorkerRepository {
  FakeWorkerRepository({this.workerProfile, this.services = const [], this.verification});

  WorkerProfile? workerProfile;
  List<WorkerService> services;
  Verification? verification;
  int verificationsSent = 0;
  int reviewRequests = 0;
  final availabilityChanges = <bool>[];

  @override
  Future<WorkerProgress> getMyProgress() async {
    final worker = workerProfile;
    if (worker == null) return WorkerProgress.notStarted;
    return WorkerProgress(
      hasProfile: true,
      hasServices: services.isNotEmpty,
      hasVerification: verification != null,
      status: worker.verificationStatus,
    );
  }

  @override
  Future<WorkerProfile?> getMyWorkerProfile() async => workerProfile;

  @override
  Future<void> saveWorkerDetails({
    required String whatsappNumber,
    required int yearsExperience,
    String? bio,
  }) async {
    workerProfile = WorkerProfile(
      id: me,
      whatsappNumber: whatsappNumber,
      yearsExperience: yearsExperience,
      bio: bio,
      isAvailable: workerProfile?.isAvailable ?? true,
      verificationStatus: workerProfile?.verificationStatus ?? VerificationStatus.pending,
      adminNotes: workerProfile?.adminNotes,
    );
  }

  @override
  Future<List<WorkerService>> getMyServices() async => services;

  @override
  Future<void> saveServices(Map<String, String?> priceNotes) async {
    services = [
      for (final entry in priceNotes.entries)
        WorkerService(workerId: me, categoryId: entry.key, priceNote: entry.value),
    ];
  }

  @override
  Future<Verification?> getMyVerification() async => verification;

  @override
  Future<void> submitVerification({Uint8List? cid, Uint8List? certificate}) async {
    verificationsSent++;
    verification = Verification(workerId: me, cidPath: '$me/cid.jpg', submittedAt: DateTime.now());
  }

  @override
  Future<void> setAvailability(bool available) async => availabilityChanges.add(available);

  @override
  Future<void> requestReview() async {
    reviewRequests++;
    final worker = workerProfile!;
    workerProfile = WorkerProfile(
      id: worker.id,
      yearsExperience: worker.yearsExperience,
      isAvailable: worker.isAvailable,
      verificationStatus: VerificationStatus.pending,
    );
  }
}

class FakeDirectoryRepository implements DirectoryRepository {
  FakeDirectoryRepository({
    this.categories = const [plumber, electrician],
    this.workers = const [],
    this.services = const {},
  });

  final List<ServiceCategory> categories;
  final List<WorkerListing> workers;
  final Map<String, List<WorkerService>> services; // by worker ID

  @override
  Future<List<ServiceCategory>> getCategories() async => categories;

  @override
  Future<List<WorkerResult>> searchWorkers({
    required String categoryId,
    required String? dzongkhag,
    required WorkerSort sort,
    bool includeUnlisted = false,
  }) async {
    return [
      for (final worker in workers)
        if ((dzongkhag == null || worker.dzongkhag == dzongkhag) &&
            (worker.isApproved || includeUnlisted))
          for (final service in services[worker.id] ?? const <WorkerService>[])
            if (service.categoryId == categoryId) (worker: worker, priceNote: service.priceNote),
    ];
  }

  @override
  Future<List<WorkerListing>> searchByName(String query) async => workers
      .where((w) => w.isApproved && w.fullName.toLowerCase().contains(query.trim().toLowerCase()))
      .toList();

  @override
  Future<WorkerDetails?> getWorker(String id) async {
    final worker = workers.where((w) => w.id == id).firstOrNull;
    return worker == null ? null : (worker: worker, services: services[id] ?? const []);
  }
}

class FakeReviewRepository implements ReviewRepository {
  FakeReviewRepository([List<Review>? reviews]) : reviews = reviews ?? [];

  final List<Review> reviews;

  @override
  Future<List<Review>> getReviews(String workerId) async =>
      reviews.where((r) => r.workerId == workerId).toList();

  @override
  Future<Review?> getMyReview(String workerId) async =>
      reviews.where((r) => r.workerId == workerId && r.customerId == me).firstOrNull;

  @override
  Future<void> saveReview({required String workerId, required int rating, String? comment}) async {
    reviews.removeWhere((r) => r.workerId == workerId && r.customerId == me);
    reviews.insert(
      0,
      Review(
        id: 'review-${reviews.length + 1}',
        workerId: workerId,
        customerId: me,
        rating: rating,
        comment: comment,
        createdAt: DateTime(2026, 9, 28),
      ),
    );
  }

  final replies = <({String reviewId, String reply})>[];

  @override
  Future<void> replyToReview(String reviewId, String reply) async {
    replies.add((reviewId: reviewId, reply: reply));
    final i = reviews.indexWhere((r) => r.id == reviewId);
    final r = reviews[i];
    reviews[i] = Review(
      id: r.id,
      workerId: r.workerId,
      customerId: r.customerId,
      rating: r.rating,
      comment: r.comment,
      createdAt: r.createdAt,
      reply: reply,
      repliedAt: DateTime(2026, 9, 29),
    );
  }
}

/// Approving or deactivating changes [directory] and [users], as the database would.
class FakeAdminRepository implements AdminRepository {
  FakeAdminRepository(this.directory, this.users, [List<Report>? reports]) : reports = reports ?? [];

  final FakeDirectoryRepository directory;
  final List<Profile> users;
  final List<Report> reports;
  final decisions = <({String workerId, String status, String? note})>[];
  final activations = <({String userId, bool active, String? reason})>[];

  @override
  Future<List<Report>> getReports({required String status}) async =>
      reports.where((r) => r.status == status).toList();

  @override
  Future<void> setReportStatus(String reportId, String status) async {
    final i = reports.indexWhere((r) => r.id == reportId);
    final r = reports[i];
    reports[i] = Report(
      id: r.id,
      workerId: r.workerId,
      workerName: r.workerName,
      reporterName: r.reporterName,
      reporterEmail: r.reporterEmail,
      reason: r.reason,
      details: r.details,
      status: status,
      createdAt: r.createdAt,
    );
  }

  @override
  Future<List<WorkerListing>> getPendingWorkers() async =>
      directory.workers.where((w) => w.verificationStatus == VerificationStatus.pending).toList();

  @override
  Future<WorkerDocuments?> getDocuments(String workerId) async => null;

  @override
  Future<void> setVerification(String workerId, String status, {String? note}) async {
    decisions.add((workerId: workerId, status: status, note: note));
    _updateWorker(workerId, status: status);
  }

  @override
  Future<List<Profile>> getUsers({String search = ''}) async => users
      .where((u) =>
          u.fullName.toLowerCase().contains(search.toLowerCase()) ||
          (u.email ?? '').toLowerCase().contains(search.toLowerCase()))
      .toList();

  @override
  Future<void> setUserActive(String userId, {required bool active, String? reason}) async {
    activations.add((userId: userId, active: active, reason: reason));
    final i = users.indexWhere((u) => u.id == userId);
    if (i >= 0) {
      final u = users[i];
      users[i] = Profile(
        id: u.id,
        fullName: u.fullName,
        role: u.role,
        email: u.email,
        isActive: active,
        deactivatedReason: active ? null : reason,
      );
    }
    _updateWorker(userId, isActive: active);
  }

  void _updateWorker(String id, {String? status, bool? isActive}) {
    final i = directory.workers.indexWhere((w) => w.id == id);
    if (i < 0) return;
    final w = directory.workers[i];
    directory.workers[i] = WorkerListing(
      id: w.id,
      fullName: w.fullName,
      dzongkhag: w.dzongkhag,
      town: w.town,
      bio: w.bio,
      yearsExperience: w.yearsExperience,
      whatsappNumber: w.whatsappNumber,
      isAvailable: w.isAvailable,
      avgRating: w.avgRating,
      reviewCount: w.reviewCount,
      verificationStatus: status ?? w.verificationStatus,
      isActive: isActive ?? w.isActive,
    );
  }
}

class FakeReportRepository implements ReportRepository {
  final reports = <({String workerId, String reason, String? details})>[];

  @override
  Future<void> submitReport({required String workerId, required String reason, String? details}) async {
    reports.add((workerId: workerId, reason: reason, details: details));
  }
}

/// Like Realtime, every change sends the whole list again, newest first.
/// [arrive] is a notification the database has just added.
class FakeNotificationRepository implements NotificationRepository {
  FakeNotificationRepository([List<AppNotification>? notifications])
      : notifications = notifications ?? [];

  final List<AppNotification> notifications;
  final _changes = StreamController<List<AppNotification>>.broadcast();

  void arrive(AppNotification notification) {
    notifications.insert(0, notification);
    _changes.add([...notifications]);
  }

  @override
  Stream<List<AppNotification>> watchMine() async* {
    yield [...notifications];
    yield* _changes.stream;
  }

  @override
  Future<void> markRead(String id) async => _markRead((n) => n.id == id);

  @override
  Future<void> markAllRead() async => _markRead((_) => true);

  void _markRead(bool Function(AppNotification) which) {
    for (final (i, n) in notifications.indexed) {
      if (which(n)) notifications[i] = n.markedRead(DateTime(2026, 9, 29));
    }
    _changes.add([...notifications]);
  }
}

/// Counts registrations; [tap] is the user tapping a push notification.
class FakePushRepository implements PushRepository {
  int registrations = 0;
  int unregistrations = 0;
  final _taps = StreamController<Map<String, dynamic>>.broadcast();

  void tap(Map<String, dynamic> data) => _taps.add(data);

  @override
  Future<void> register() async => registrations++;

  @override
  Future<void> unregister() async => unregistrations++;

  @override
  Stream<Map<String, dynamic>> get openedNotifications => _taps.stream;
}

/// [contacted]: workers the customer has been in touch with, so may review.
class FakeContactRepository implements ContactRepository {
  FakeContactRepository(this.contacted);

  final Set<String> contacted;
  final recorded = <({String workerId, String method})>[];

  @override
  Future<void> recordContact(String workerId, String method) async {
    recorded.add((workerId: workerId, method: method));
    contacted.add(workerId);
  }

  @override
  Future<bool> hasContacted(String workerId) async => contacted.contains(workerId);
}

/// [saved] holds worker IDs, most recently saved first.
class FakeSavedWorkersRepository implements SavedWorkersRepository {
  FakeSavedWorkersRepository(this.directory, this.saved);

  final FakeDirectoryRepository directory;
  final List<String> saved;

  @override
  Future<List<WorkerListing>> getSavedWorkers() async => [
        for (final id in saved)
          ...directory.workers.where((w) => w.id == id && w.isApproved && w.isActive),
      ];

  @override
  Future<bool> isSaved(String workerId) async => saved.contains(workerId);

  @override
  Future<void> setSaved(String workerId, {required bool saved}) async {
    this.saved.remove(workerId);
    if (saved) this.saved.insert(0, workerId);
  }
}

/// Photos by worker ID. Adding needs the phone's camera, so tests don't.
class FakeWorkPhotoRepository implements WorkPhotoRepository {
  FakeWorkPhotoRepository(this.photos);

  final Map<String, List<WorkPhoto>> photos;

  @override
  Future<List<WorkPhoto>> getPhotos(String workerId) async => [...?photos[workerId]];

  @override
  Future<void> addPhoto(Uint8List photo) async {
    final mine = photos.putIfAbsent(me, () => []);
    mine.insert(0, WorkPhoto(id: 'photo-${mine.length + 1}', workerId: me, path: '$me/new.jpg', url: ''));
  }

  @override
  Future<void> deletePhoto(WorkPhoto photo) async => photos[photo.workerId]?.remove(photo);
}

/// Like the database: one open request per customer and worker, and only
/// allowed status changes. [me] is the customer or the worker.
class FakeJobRepository implements JobRepository {
  FakeJobRepository(this.jobs);

  final List<JobRequest> jobs;
  final photosSent = <Uint8List>[];

  @override
  Future<List<JobRequest>> getMyJobs({required bool asWorker}) async =>
      jobs.where((j) => (asWorker ? j.workerId : j.customerId) == me).toList();

  @override
  Future<void> sendRequest({
    required String workerId,
    String? categoryId,
    required String description,
    String? whenNeeded,
    required String address,
    required String contactPhone,
    Uint8List? photo,
  }) async {
    if (jobs.any((j) => j.customerId == me && j.workerId == workerId && j.isOpen)) {
      throw const PostgrestException(message: 'duplicate key value', code: '23505');
    }
    if (photo != null) photosSent.add(photo);
    jobs.insert(
      0,
      JobRequest(
        id: 'job-${jobs.length + 1}',
        customerId: me,
        workerId: workerId,
        customerName: 'Test',
        description: description,
        whenNeeded: whenNeeded,
        address: address,
        contactPhone: contactPhone,
        status: JobStatus.pending,
        createdAt: DateTime.now(),
      ),
    );
  }

  @override
  Future<void> setStatus(String requestId, String status, {String? note}) async {
    final i = jobs.indexWhere((j) => j.id == requestId);
    final accepting = status == JobStatus.accepted || status == JobStatus.declined;
    jobs[i] = jobs[i].withStatus(status, note: accepting && (note ?? '').isNotEmpty ? note : null);
  }

  @override
  Future<String> photoUrl(String path) async => 'https://example.com/$path';
}

/// Like the database: customers see listed venues (with an active manager,
/// and a ground taking bookings with some timings); their manager ([me]) and
/// admins see any.
/// Free times come from the open [bookings], which FakeBookingRepository shares.
class FakeVenueRepository implements VenueRepository {
  FakeVenueRepository({
    required this.venues,
    required this.grounds,
    required this.reviews,
    required this.bookings,
    this.viewerIsAdmin = false,
  });

  final List<Venue> venues;
  final List<Ground> grounds;
  final List<VenueReview> reviews;
  final List<GroundBooking> bookings;
  final bool viewerIsAdmin;
  final regulars = <RegularBooking>[]; // FakeBookingRepository adds and removes them
  final added = <VenueDraft>[];
  final savedGrounds = <GroundDraft>[];
  final savedSlots = <({String groundId, List<TimeSlot> slots})>[];
  final accounts = <({String email, String fullName, String? phone})>[];
  final managerChanges = <({String venueId, String? managerId})>[];
  bool managerNotAllowed = false; // the email is an admin's or a worker's

  bool _listed(Venue v) =>
      v.isListed && grounds.any((g) => g.venueId == v.id && g.isActive && g.slots.isNotEmpty);

  void _replace(String id, Venue Function(Venue v) change) {
    final i = venues.indexWhere((v) => v.id == id);
    venues[i] = change(venues[i]);
  }

  @override
  Future<List<Venue>> getVenues({String? dzongkhag}) async =>
      venues.where((v) => _listed(v) && (dzongkhag == null || v.dzongkhag == dzongkhag)).toList();

  @override
  Future<List<Venue>> searchVenues(String query) async {
    final term = query.trim().toLowerCase();
    return venues
        .where((v) =>
            _listed(v) &&
            [v.name, v.town ?? '', v.dzongkhag].any((field) => field.toLowerCase().contains(term)))
        .toList();
  }

  @override
  Future<VenueDetails?> getVenue(String id) async {
    final venue = venues.where((v) => v.id == id).firstOrNull;
    if (venue == null || !(_listed(venue) || venue.managerId == me || viewerIsAdmin)) return null;
    return (venue: venue, grounds: grounds.where((g) => g.venueId == id).toList());
  }

  @override
  Future<List<BusyTime>> getAvailability(String groundId, DateTime day) async => [
        for (final r in regulars)
          if (r.groundId == groundId && r.weekday == BhutanTime.weekdayOf(day))
            (start: BhutanTime.at(day, r.startHour), end: BhutanTime.at(day, r.endHour), blocked: false, confirmed: true, regular: true),
        for (final b in bookings)
          if (b.groundId == groundId && b.isOpen && BhutanTime.dayOf(b.startsAt) == day)
            (
              start: b.startsAt,
              end: b.endsAt,
              blocked: b.isBlock,
              confirmed: b.status == BookingStatus.confirmed,
              regular: false,
            ),
      ];

  @override
  Future<List<VenueReview>> getReviews(String venueId) async => reviews.where((r) => r.venueId == venueId).toList();

  @override
  Future<VenueReview?> getMyReview(String venueId) async =>
      reviews.where((r) => r.venueId == venueId && r.customerId == me).firstOrNull;

  @override
  Future<void> saveReview({required String venueId, required int rating, String? comment}) async {
    reviews.removeWhere((r) => r.venueId == venueId && r.customerId == me);
    reviews.insert(
      0,
      VenueReview(
          id: 'review-${reviews.length + 1}',
          venueId: venueId,
          customerId: me,
          rating: rating,
          comment: comment,
          createdAt: DateTime(2026, 9, 30)),
    );
  }

  @override
  Future<List<Venue>> getMyVenues() async => venues.where((v) => v.managerId == me).toList();

  @override
  Future<void> updateVenue(String venueId, VenueDraft draft, {Uint8List? cover}) async =>
      _replace(venueId, (v) => venueFrom(draft, id: venueId, manager: v.managerId, active: v.isActive));

  @override
  Future<void> setVenueActive(String venueId, bool active) async =>
      _replace(venueId, (v) => venueFrom(_draftOf(v), id: v.id, manager: v.managerId, active: active));

  /// Like the grounds row: its type and price; the timings stay.
  @override
  Future<void> saveGround(String venueId, GroundDraft draft) async {
    savedGrounds.add(draft);
    final old = grounds.where((g) => g.id == draft.id).firstOrNull;
    grounds.removeWhere((g) => g.id == draft.id);
    grounds.add(groundFrom(draft, id: draft.id ?? 'ground-new-${savedGrounds.length}', venueId: venueId,
        slots: old?.slots ?? const []));
  }

  @override
  Future<void> saveTimeSlots(String groundId, List<TimeSlot> slots) async {
    savedSlots.add((groundId: groundId, slots: slots));
    final i = grounds.indexWhere((g) => g.id == groundId);
    final g = grounds[i];
    grounds[i] = Ground(
      id: g.id,
      venueId: g.venueId,
      name: g.name,
      sport: g.sport,
      pricePerHourNu: g.pricePerHourNu,
      eveningPriceNu: g.eveningPriceNu,
      eveningFromHour: g.eveningFromHour,
      isActive: g.isActive,
      slots: [...slots.toSet()]..sort(TimeSlot.byTime),
    );
  }

  @override
  Future<List<Venue>> getAllVenues() async => [...venues];

  /// Like add_venue: the venue, its manager and its type and price, or none of them.
  @override
  Future<String> addVenue(VenueDraft draft,
      {required String managerId, required GroundDraft ground, Uint8List? cover}) async {
    if (managerNotAllowed) {
      throw const PostgrestException(message: "This account can't manage a venue", code: '22023');
    }
    added.add(draft);
    final id = 'venue-new-${added.length}';
    final account = accounts.lastOrNull;
    venues.add(venueFrom(draft,
        id: id, manager: managerId, managerName: account?.fullName, managerEmail: account?.email));
    savedGrounds.add(ground);
    grounds.add(groundFrom(ground, id: 'ground-new-${savedGrounds.length}', venueId: id));
    return id;
  }

  @override
  Future<ManagerAccount> createManagerAccount({required String email, required String fullName, String? phone}) async {
    accounts.add((email: email, fullName: fullName, phone: phone));
    return (userId: 'manager-${accounts.length}', created: true);
  }

  @override
  Future<void> setVenueManager(String venueId, String? managerId) async {
    if (managerNotAllowed) {
      throw const PostgrestException(message: "This account can't manage a venue", code: '22023');
    }
    managerChanges.add((venueId: venueId, managerId: managerId));
    final account = managerId == null ? null : accounts.lastOrNull;
    _replace(
      venueId,
      (v) => venueFrom(_draftOf(v),
          id: v.id, manager: managerId, managerName: account?.fullName, managerEmail: account?.email, active: v.isActive),
    );
  }

  static VenueDraft _draftOf(Venue v) => VenueDraft(
      name: v.name, dzongkhag: v.dzongkhag, phone: v.phone, autoConfirm: v.autoConfirm, coordinates: v.coordinates);
}

/// The phone's location: [position], once the app may use it ([allowed]).
/// Asking ([current]) allows it, unless [problem] says what goes wrong.
/// [links]: short Google Maps links and where they lead; other text is read
/// as the app reads it.
class FakeLocationService implements LocationService {
  FakeLocationService({this.position, this.allowed = false});

  GeoPoint? position;
  bool allowed;
  LocationProblem? problem;
  int asked = 0;
  final links = <String, GeoPoint>{};
  final settingsOpened = <LocationProblem>[];

  @override
  Future<GeoPoint?> currentIfAllowed() async => allowed ? position : null;

  @override
  Future<GeoPoint> current({bool precise = false}) async {
    asked++;
    final problem = this.problem;
    if (problem != null) throw LocationUnavailable(problem);
    allowed = true;
    return position ?? (throw const LocationUnavailable(LocationProblem.unavailable));
  }

  @override
  Future<void> openSettings(LocationProblem problem) async => settingsOpened.add(problem);

  @override
  Future<GeoPoint?> resolveMapsLink(String text) async => links[text.trim()] ?? MapsLink.parse(text);
}

/// Like the database: bookings of one ground can't overlap (23P01), and
/// cancelling records who did it. [takeNextBooking]: someone else books the
/// time just before the customer does.
class FakeBookingRepository implements BookingRepository {
  FakeBookingRepository(this.bookings, this.venues);

  final List<GroundBooking> bookings;
  final FakeVenueRepository venues;
  final booked = <({String groundId, DateTime start, int hours, String phone, String? team, String payment})>[];
  final blocks = <({String groundId, DateTime start, DateTime end, String? reason})>[];
  bool takeNextBooking = false;

  void _replace(String id, GroundBooking Function(GroundBooking b) change) {
    final i = bookings.indexWhere((b) => b.id == id);
    bookings[i] = change(bookings[i]);
  }

  bool _overlaps(String groundId, DateTime start, DateTime end) =>
      bookings.any((b) => b.groundId == groundId && b.isOpen && b.startsAt.isBefore(end) && b.endsAt.isAfter(start));

  @override
  Future<List<GroundBooking>> getMyBookings() async =>
      bookings.where((b) => b.bookedBy == me && !b.isBlock).toList()..sort((a, b) => b.startsAt.compareTo(a.startsAt));

  @override
  Future<List<GroundBooking>> getVenueBookings(String venueId) async =>
      bookings.where((b) => b.venueId == venueId).toList();

  @override
  Future<String> book({
    required String groundId,
    required DateTime start,
    required int hours,
    required String phone,
    String? team,
    int? players,
    String payment = PaymentMethod.payAtVenue,
    String? paymentRef,
    String? note,
  }) async {
    final end = start.add(Duration(hours: hours));
    if (takeNextBooking || _overlaps(groundId, start, end)) {
      takeNextBooking = false;
      throw const PostgrestException(message: 'Someone else has just booked this time', code: '23P01');
    }
    booked.add((groundId: groundId, start: start, hours: hours, phone: phone, team: team, payment: payment));
    final ground = venues.grounds.firstWhere((g) => g.id == groundId);
    final venue = venues.venues.firstWhere((v) => v.id == ground.venueId);
    final id = 'booking-new-${booked.length}';
    bookings.add(groundBooking(
      id: id,
      venue: venue,
      ground: ground,
      start: start,
      hours: hours,
      status: venue.autoConfirm ? BookingStatus.confirmed : BookingStatus.pending,
      team: team,
    ));
    return id;
  }

  @override
  Future<void> setStatus(String bookingId, String status, {String? note}) async => _replace(
        bookingId,
        (b) => b.copyWith(
          status: status,
          ownerNote: b.bookedBy != me && (note ?? '').isNotEmpty ? note : null,
          cancelledBy: status == BookingStatus.cancelled ? me : null,
        ),
      );

  @override
  Future<List<GroundBooking>> getBookingRecords(String venueId) async =>
      bookings.where((b) => b.venueId == venueId && !b.isBlock).toList()
        ..sort((a, b) => b.startsAt.compareTo(a.startsAt));

  @override
  Future<List<RegularBooking>> getRegularBookings(String groundId) async =>
      venues.regulars.where((r) => r.groundId == groundId).toList();

  /// Like add_regular_bookings: all or none, and two can't share any time on
  /// the same day.
  @override
  Future<List<String>> addRegularBookings({
    required String groundId,
    required List<TimeSlot> slots,
    required String name,
    String? phone,
    String? team,
  }) async {
    final added = <RegularBooking>[];
    for (final slot in slots) {
      if ([...venues.regulars, ...added].any((r) =>
          r.groundId == groundId && r.weekday == slot.weekday && r.startHour < slot.endHour && slot.startHour < r.endHour)) {
        throw const PostgrestException(message: 'Another regular booking has this time', code: '23P01');
      }
      added.add(RegularBooking(
        id: 'regular-${venues.regulars.length + added.length + 1}',
        groundId: groundId,
        weekday: slot.weekday,
        startHour: slot.startHour,
        endHour: slot.endHour,
        name: name,
        phone: phone,
        teamName: team,
      ));
    }
    venues.regulars.addAll(added);
    return [for (final r in added) r.id];
  }

  /// Like update_regular_booking: it can't move onto another one's time.
  @override
  Future<void> updateRegularBooking({
    required String regularId,
    required TimeSlot slot,
    required String name,
    String? phone,
    String? team,
  }) async {
    final i = venues.regulars.indexWhere((r) => r.id == regularId);
    final old = venues.regulars[i];
    if (venues.regulars.any((r) =>
        r.id != regularId &&
        r.groundId == old.groundId &&
        r.weekday == slot.weekday &&
        r.startHour < slot.endHour &&
        slot.startHour < r.endHour)) {
      throw const PostgrestException(message: 'Another regular booking has this time', code: '23P01');
    }
    venues.regulars[i] = RegularBooking(
      id: regularId,
      groundId: old.groundId,
      weekday: slot.weekday,
      startHour: slot.startHour,
      endHour: slot.endHour,
      name: name,
      phone: phone,
      teamName: team,
    );
  }

  /// Like make_booking_regular: the booking's day and time, for the same person.
  @override
  Future<String> makeRegular(String bookingId) async {
    final b = bookings.firstWhere((b) => b.id == bookingId);
    final ids = await addRegularBookings(
        groundId: b.groundId, slots: [b.weeklyTime], name: b.contactName, phone: b.contactPhone, team: b.teamName);
    return ids.single;
  }

  @override
  Future<void> removeRegularBooking(String regularId) async => venues.regulars.removeWhere((r) => r.id == regularId);

  final phoneBookings = <({DateTime start, int hours, String name, String? phone})>[];

  /// Like book_by_phone: confirmed at once, unless the time is taken.
  @override
  Future<String> bookByPhone({
    required String groundId,
    required DateTime start,
    required int hours,
    required String name,
    String? phone,
    String? team,
  }) async {
    if (_overlaps(groundId, start, start.add(Duration(hours: hours)))) {
      throw const PostgrestException(message: 'This time is already booked', code: '23P01');
    }
    phoneBookings.add((start: start, hours: hours, name: name, phone: phone));
    final ground = venues.grounds.firstWhere((g) => g.id == groundId);
    final venue = venues.venues.firstWhere((v) => v.id == ground.venueId);
    final id = 'phone-booking-${phoneBookings.length}';
    bookings.add(groundBooking(
      id: id,
      venue: venue,
      ground: ground,
      start: start,
      hours: hours,
      kind: BookingKind.phone,
      contactName: name,
      contactPhone: phone,
      status: BookingStatus.confirmed,
      team: team,
    ));
    return id;
  }

  @override
  Future<void> blockTime({required String groundId, required DateTime start, required DateTime end, String? reason}) async {
    if (_overlaps(groundId, start, end)) {
      throw const PostgrestException(message: 'A booking already has some of this time', code: '23P01');
    }
    blocks.add((groundId: groundId, start: start, end: end, reason: reason));
  }

  @override
  Future<void> setPaymentRef(String bookingId, String? reference) async => _replace(bookingId,
      (b) => b.copyWith(paymentReference: reference, paymentStatus: PaymentStatus.depositClaimed));

  @override
  Future<void> setPaid(String bookingId, bool paid) async => _replace(
      bookingId, (b) => b.copyWith(paymentStatus: paid ? PaymentStatus.paid : PaymentStatus.unpaid));
}

// Test data.

const plumber = ServiceCategory(id: 'cat-plumber', name: 'Plumber', icon: 'plumber', isActive: true);
const electrician =
    ServiceCategory(id: 'cat-electrician', name: 'Electrician', icon: 'electrician', isActive: true);

WorkerListing listing({
  required String id,
  required String name,
  String dzongkhag = 'Thimphu',
  String? town,
  double rating = 4.5,
  int reviewCount = 2,
  int years = 5,
  bool available = true,
  String status = VerificationStatus.approved,
}) =>
    WorkerListing(
      verificationStatus: status,
      id: id,
      fullName: name,
      dzongkhag: dzongkhag,
      town: town,
      bio: 'I fix taps and pipes.',
      yearsExperience: years,
      whatsappNumber: '+97517123456',
      isAvailable: available,
      avgRating: rating,
      reviewCount: reviewCount,
    );

AppNotification notice(
  String type, {
  String? id,
  Map<String, dynamic> data = const {},
  bool read = false,
}) =>
    AppNotification(
      id: id ?? type,
      type: type,
      data: data,
      createdAt: DateTime.now().subtract(const Duration(minutes: 5)),
      readAt: read ? DateTime(2026, 9, 28) : null,
    );

/// A venue made from what was filled in, run by [manager] (none: null).
Venue venueFrom(
  VenueDraft draft, {
  required String id,
  required String? manager,
  String? managerName,
  String? managerEmail,
  bool active = true,
}) =>
    Venue(
      id: id,
      managerId: manager,
      managerName: manager == null ? null : managerName ?? 'Tashi Dorji',
      managerEmail: manager == null ? null : managerEmail ?? 'tashi@example.com',
      name: draft.name,
      dzongkhag: draft.dzongkhag,
      phone: draft.phone,
      autoConfirm: draft.autoConfirm,
      coordinates: draft.coordinates,
      isActive: active,
      sports: const [Sport.futsal],
      groundCount: 1,
      fromPriceNu: 1000,
    );

/// A futsal venue run by 'tashi' unless [manager] says otherwise (null: no
/// manager yet); taking bookings.
Venue venue({
  String id = 'venue-1',
  String? manager = 'tashi',
  String name = 'Changli Futsal',
  String dzongkhag = 'Thimphu',
  bool autoConfirm = false,
  GeoPoint? coordinates,
}) =>
    venueFrom(
      VenueDraft(
          name: name, dzongkhag: dzongkhag, phone: '+97517111111', autoConfirm: autoConfirm, coordinates: coordinates),
      id: id,
      manager: manager,
    );

/// Every day's times at the test ground: 8-10 am, 4-6 pm, 6-8 pm, 7-9 pm
/// (running into the ones either side) and 8-10 pm.
final everyDaySlots = [
  for (var day = 0; day < 7; day++)
    for (final (start, end) in const [(8, 10), (16, 18), (18, 20), (19, 21), (20, 22)])
      TimeSlot(weekday: day, startHour: start, endHour: end),
];

/// Nu 1,000 an hour, Nu 1,500 from 5 pm; [everyDaySlots] unless [slots] says otherwise.
Ground ground({String id = 'ground-1', String venueId = 'venue-1', List<TimeSlot>? slots}) => Ground(
      id: id,
      venueId: venueId,
      name: 'Changli Futsal',
      pricePerHourNu: 1000,
      eveningPriceNu: 1500,
      eveningFromHour: 17,
      slots: slots ?? everyDaySlots,
    );

/// A ground made from what was filled in.
Ground groundFrom(GroundDraft draft, {required String id, required String venueId, List<TimeSlot> slots = const []}) =>
    Ground(
      id: id,
      venueId: venueId,
      name: draft.name,
      sport: draft.sport,
      pricePerHourNu: draft.pricePerHourNu,
      eveningPriceNu: draft.eveningPriceNu,
      eveningFromHour: draft.eveningFromHour,
      slots: slots,
    );

/// Tomorrow (Bhutan time) at [hour] o'clock.
DateTime tomorrowAt(int hour) => BhutanTime.at(BhutanTime.today().add(const Duration(days: 1)), hour);

GroundBooking groundBooking({
  String id = 'booking-1',
  required Venue venue,
  required Ground ground,
  required DateTime start,
  int hours = 1,
  String bookedBy = me,
  String kind = BookingKind.customer,
  String contactName = 'Test',
  String? contactPhone = '+97517999999',
  String status = BookingStatus.pending,
  String? team,
}) =>
    GroundBooking(
      id: id,
      groundId: ground.id,
      bookedBy: bookedBy,
      kind: kind,
      startsAt: start,
      endsAt: start.add(Duration(hours: hours)),
      status: status,
      priceNu: ground.priceFor(BhutanTime.of(start).hour, hours),
      teamName: team,
      contactName: contactName,
      contactPhone: contactPhone,
      createdAt: DateTime.now().subtract(const Duration(hours: 1)),
      groundName: ground.name,
      venueId: venue.id,
      managerId: venue.managerId,
      venueName: venue.name,
      venueDzongkhag: venue.dzongkhag,
      venuePhone: venue.phone,
      freeCancelHours: venue.freeCancelHours,
    );

WorkerService offers(String workerId, ServiceCategory category, {String? price}) => WorkerService(
      workerId: workerId,
      categoryId: category.id,
      priceNote: price,
      categoryName: category.name,
      categoryIcon: category.icon,
    );

/// Every fake, for checking what the app did.
class Fakes {
  Fakes({
    required this.auth,
    required this.profile,
    required this.worker,
    required this.directory,
    required this.reviews,
    required this.reports,
    required this.admin,
    required this.notifications,
    required this.contacts,
    required this.saved,
    required this.workPhotos,
    required this.jobs,
    required this.push,
    required this.venues,
    required this.bookings,
    required this.location,
  });

  final FakeAuthRepository auth;
  final FakeProfileRepository profile;
  final FakeWorkerRepository worker;
  final FakeDirectoryRepository directory;
  final FakeReviewRepository reviews;
  final FakeReportRepository reports;
  final FakeAdminRepository admin;
  final FakeNotificationRepository notifications;
  final FakeContactRepository contacts;
  final FakeSavedWorkersRepository saved;
  final FakeWorkPhotoRepository workPhotos;
  final FakeJobRepository jobs;
  final FakePushRepository push;
  final FakeVenueRepository venues;
  final FakeBookingRepository bookings;
  final FakeLocationService location;
}

Future<Fakes> pumpApp(
  WidgetTester tester, {
  String role = UserRole.customer,
  List<String> roles = const [], // other roles the account has (profiles.roles)
  bool loggedIn = false,
  bool hasPassword = false,
  FakeWorkerRepository? worker,
  FakeDirectoryRepository? directory,
  FakeReviewRepository? reviews,
  Map<String, Object> savedSettings = const {},
  bool active = true,
  String? deactivatedReason,
  List<Profile> users = const [], // what an admin sees under Users
  List<AppNotification> notifications = const [],
  List<Report> reports = const [], // what an admin sees under Reports
  Set<String> contacted = const {}, // workers the customer may review
  List<String> saved = const [],
  Map<String, List<WorkPhoto>> workPhotos = const {},
  List<JobRequest> jobs = const [],
  List<Venue> venues = const [],
  List<Ground> grounds = const [],
  List<GroundBooking> bookings = const [],
  List<VenueReview> venueReviews = const [],
  GeoPoint? myPosition, // where the phone is
  bool locationAllowed = false, // the app may already use it
  bool locationAskedBefore = true, // false: first launch, when the app asks once by itself
}) async {
  // A phone-sized screen (iPhone 16).
  tester.view.physicalSize = const Size(1179, 2556);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  SharedPreferences.setMockInitialValues({
    if (locationAskedBefore) MyPosition.askedKey: true,
    ...savedSettings,
  });

  directory ??= FakeDirectoryRepository();
  final venueFake = FakeVenueRepository(
    venues: [...venues],
    grounds: [...grounds],
    reviews: [...venueReviews],
    bookings: [...bookings],
    viewerIsAdmin: role == UserRole.admin,
  );
  final fakes = Fakes(
    auth: FakeAuthRepository(loggedIn: loggedIn, hasPassword: hasPassword),
    profile: FakeProfileRepository(Profile(
      id: me,
      fullName: 'Test',
      role: role,
      roles: {role, ...roles}.toList(),
      email: 'test@example.com',
      isActive: active,
      deactivatedReason: deactivatedReason,
    )),
    worker: worker ?? FakeWorkerRepository(),
    directory: directory,
    reviews: reviews ?? FakeReviewRepository(),
    reports: FakeReportRepository(),
    admin: FakeAdminRepository(directory, [...users], [...reports]),
    notifications: FakeNotificationRepository([...notifications]),
    contacts: FakeContactRepository({...contacted}),
    saved: FakeSavedWorkersRepository(directory, [...saved]),
    workPhotos: FakeWorkPhotoRepository({for (final e in workPhotos.entries) e.key: [...e.value]}),
    jobs: FakeJobRepository([...jobs]),
    push: FakePushRepository(),
    venues: venueFake,
    bookings: FakeBookingRepository(venueFake.bookings, venueFake),
    location: FakeLocationService(position: myPosition, allowed: locationAllowed),
  );
  await tester.pumpWidget(ProviderScope(
    overrides: [
      authRepositoryProvider.overrideWithValue(fakes.auth),
      profileRepositoryProvider.overrideWithValue(fakes.profile),
      workerRepositoryProvider.overrideWithValue(fakes.worker),
      directoryRepositoryProvider.overrideWithValue(fakes.directory),
      reviewRepositoryProvider.overrideWithValue(fakes.reviews),
      reportRepositoryProvider.overrideWithValue(fakes.reports),
      adminRepositoryProvider.overrideWithValue(fakes.admin),
      notificationRepositoryProvider.overrideWithValue(fakes.notifications),
      contactRepositoryProvider.overrideWithValue(fakes.contacts),
      savedWorkersRepositoryProvider.overrideWithValue(fakes.saved),
      workPhotoRepositoryProvider.overrideWithValue(fakes.workPhotos),
      jobRepositoryProvider.overrideWithValue(fakes.jobs),
      pushRepositoryProvider.overrideWithValue(fakes.push),
      venueRepositoryProvider.overrideWithValue(fakes.venues),
      bookingRepositoryProvider.overrideWithValue(fakes.bookings),
      locationServiceProvider.overrideWithValue(fakes.location),
    ],
    child: const BhutanServicesApp(),
  ));
  await tester.pumpAndSettle();
  return fakes;
}

Future<void> enterField(WidgetTester tester, String label, String value) =>
    tester.enterText(find.widgetWithText(TextFormField, label), value);

Future<void> tapAndSettle(WidgetTester tester, String text) async {
  await tester.tap(find.text(text));
  await tester.pumpAndSettle();
}

/// Scrolls the screen's list until [finder] shows, then taps it.
Future<void> scrollAndTap(WidgetTester tester, Finder finder) async {
  await tester.dragUntilVisible(finder, find.byType(Scrollable).first, const Offset(0, -250));
  await tester.pumpAndSettle(); // let the drag's fling stop, so the tap lands where the widget is
  await tester.tap(finder);
  await tester.pumpAndSettle();
}
