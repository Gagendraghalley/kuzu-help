import 'dart:async';
import 'dart:typed_data';

import 'package:bhutan_services/app.dart';
import 'package:bhutan_services/core/constants/app_constants.dart';
import 'package:bhutan_services/features/admin/data/admin_repository.dart';
import 'package:bhutan_services/features/auth/data/auth_repository.dart';
import 'package:bhutan_services/features/customer/data/contact_repository.dart';
import 'package:bhutan_services/features/customer/data/directory_repository.dart';
import 'package:bhutan_services/features/customer/data/report_repository.dart';
import 'package:bhutan_services/features/customer/data/review_repository.dart';
import 'package:bhutan_services/features/customer/data/saved_workers_repository.dart';
import 'package:bhutan_services/features/jobs/data/job_repository.dart';
import 'package:bhutan_services/features/notifications/data/notification_repository.dart';
import 'package:bhutan_services/features/profile/data/profile_repository.dart';
import 'package:bhutan_services/features/worker/data/work_photo_repository.dart';
import 'package:bhutan_services/features/worker/data/worker_repository.dart';
import 'package:bhutan_services/shared/models/app_notification.dart';
import 'package:bhutan_services/shared/models/job_request.dart';
import 'package:bhutan_services/shared/models/profile.dart';
import 'package:bhutan_services/shared/models/report.dart';
import 'package:bhutan_services/shared/models/review.dart';
import 'package:bhutan_services/shared/models/service_category.dart';
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
    profile = Profile(id: profile.id, fullName: profile.fullName, role: to, email: profile.email);
  }
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
}

Future<Fakes> pumpApp(
  WidgetTester tester, {
  String role = UserRole.customer,
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
}) async {
  // A phone-sized screen (iPhone 16).
  tester.view.physicalSize = const Size(1179, 2556);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  SharedPreferences.setMockInitialValues(savedSettings);

  directory ??= FakeDirectoryRepository();
  final fakes = Fakes(
    auth: FakeAuthRepository(loggedIn: loggedIn, hasPassword: hasPassword),
    profile: FakeProfileRepository(Profile(
      id: me,
      fullName: 'Test',
      role: role,
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
