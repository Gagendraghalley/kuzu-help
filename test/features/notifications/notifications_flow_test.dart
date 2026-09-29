import 'package:bhutan_services/core/constants/app_constants.dart';
import 'package:bhutan_services/core/strings/app_strings.dart';
import 'package:bhutan_services/shared/models/verification.dart';
import 'package:bhutan_services/shared/models/worker_profile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fakes.dart';

// Notifications: the bell on each home screen, and what tapping one opens.

Finder bellCount(String count) => find.descendant(of: find.byType(Badge), matching: find.text(count));

Future<void> openBell(WidgetTester tester) async {
  await tester.tap(find.byTooltip(AppStrings.notifications));
  await tester.pumpAndSettle();
}

String title(String type, [Map<String, dynamic> data = const {}]) =>
    AppStrings.notificationTitle(type, data);

WorkerProfile workerProfile(String status) => WorkerProfile(
      id: me,
      yearsExperience: 5,
      whatsappNumber: '+97517123456',
      isAvailable: true,
      verificationStatus: status,
    );

FakeWorkerRepository sentEverything(String status) => FakeWorkerRepository(
      workerProfile: workerProfile(status),
      services: [offers(me, plumber)],
      verification: Verification(workerId: me, cidPath: '$me/cid.jpg', submittedAt: DateTime(2026, 9, 1)),
    );

void main() {
  testWidgets('the bell shows how many are unread, and lists them', (tester) async {
    await pumpApp(tester, loggedIn: true, hasPassword: true, notifications: [
      notice(NotificationTypes.welcome, data: {'role': UserRole.customer}),
      notice(NotificationTypes.accountReactivated, read: true),
    ]);
    expect(bellCount('1'), findsOneWidget);

    await openBell(tester);
    expect(find.text(title(NotificationTypes.welcome)), findsOneWidget);
    expect(find.text('Choose a service to find trusted local workers near you.'), findsOneWidget);
    expect(find.text(title(NotificationTypes.accountReactivated)), findsOneWidget);
    expect(find.text('5 min ago'), findsNWidgets(2));
  });

  testWidgets('with none, the bell has no number and the list says so', (tester) async {
    await pumpApp(tester, loggedIn: true, hasPassword: true);
    expect(find.byType(Badge), findsOneWidget);
    expect(bellCount('0'), findsNothing);

    await openBell(tester);
    expect(find.text(AppStrings.noNotifications), findsOneWidget);
    expect(find.text(AppStrings.markAllRead), findsNothing);
  });

  testWidgets('a new one shows on the bell straight away', (tester) async {
    final fakes = await pumpApp(tester, loggedIn: true, hasPassword: true);

    fakes.notifications.arrive(notice(NotificationTypes.reportUpdated,
        data: {'worker_name': 'Pema Dorji', 'status': 'reviewed'}));
    await tester.pumpAndSettle();
    expect(bellCount('1'), findsOneWidget);

    await openBell(tester);
    expect(find.text('Update on your report about Pema Dorji'), findsOneWidget);
    expect(find.text('Our team has looked into it. Thank you for telling us.'), findsOneWidget);
  });

  testWidgets('Mark all as read empties the bell', (tester) async {
    final fakes = await pumpApp(tester, loggedIn: true, hasPassword: true, notifications: [
      notice(NotificationTypes.welcome),
      notice(NotificationTypes.accountReactivated),
    ]);
    expect(bellCount('2'), findsOneWidget);

    await openBell(tester);
    await tapAndSettle(tester, AppStrings.markAllRead);
    expect(fakes.notifications.notifications.every((n) => n.isRead), isTrue);
    expect(find.text(AppStrings.markAllRead), findsNothing);

    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(bellCount('2'), findsNothing);
  });

  testWidgets("admins are told a worker is waiting, and tapping opens the worker's Admin check",
      (tester) async {
    final fakes = await pumpApp(
      tester,
      role: UserRole.admin,
      loggedIn: true,
      directory: FakeDirectoryRepository(
        workers: [listing(id: 'dechen', name: 'Dechen Wangmo', status: VerificationStatus.pending)],
        services: {'dechen': [offers('dechen', plumber)]},
      ),
      notifications: [
        notice(NotificationTypes.workerSubmitted, data: {'worker_id': 'dechen', 'name': 'Dechen Wangmo'}),
        notice(NotificationTypes.newUser,
            id: 'n2', data: {'name': 'Karma Wangdi', 'email': 'karma@example.com', 'role': UserRole.worker}),
      ],
    );

    await openBell(tester);
    expect(find.text('Karma Wangdi joined as a worker'), findsOneWidget);
    expect(find.text('karma@example.com'), findsOneWidget);

    await tapAndSettle(tester, 'Dechen Wangmo is waiting for approval');
    expect(find.text(AppStrings.adminCheck), findsOneWidget);
    expect(fakes.notifications.notifications.first.isRead, isTrue);
    expect(fakes.notifications.notifications.last.isRead, isFalse);
  });

  testWidgets('a waiting worker is told they are approved, and tapping opens their dashboard',
      (tester) async {
    final fakes = await pumpApp(
      tester,
      role: UserRole.worker,
      loggedIn: true,
      hasPassword: true,
      worker: sentEverything(VerificationStatus.pending),
      directory: FakeDirectoryRepository(
        workers: [listing(id: me, name: 'Test')],
        services: {me: [offers(me, plumber)]},
      ),
    );
    expect(find.text(AppStrings.pendingTitle), findsOneWidget);

    // What set_worker_verification does in the database.
    fakes.worker.workerProfile = workerProfile(VerificationStatus.approved);
    fakes.notifications.arrive(notice(NotificationTypes.workerApproved));
    await tester.pumpAndSettle();
    expect(bellCount('1'), findsOneWidget);

    await openBell(tester);
    await tapAndSettle(tester, AppStrings.approvedTitle);
    expect(find.text(AppStrings.greeting('Test')), findsOneWidget); // B5
    expect(bellCount('1'), findsNothing);
  });

  testWidgets("workers are told about a new review, and tapping opens their page's reviews",
      (tester) async {
    await pumpApp(
      tester,
      role: UserRole.worker,
      loggedIn: true,
      hasPassword: true,
      worker: sentEverything(VerificationStatus.approved),
      directory: FakeDirectoryRepository(
        workers: [listing(id: me, name: 'Test')],
        services: {me: [offers(me, plumber)]},
      ),
      notifications: [
        notice(NotificationTypes.reviewNew, data: {'worker_id': me, 'rating': 4}),
      ],
    );

    await openBell(tester);
    await tapAndSettle(tester, 'A customer rated you 4 stars');
    expect(find.text(AppStrings.yourPublicProfile), findsOneWidget);
  });

  testWidgets("tapping Call or WhatsApp on a worker's page tells the worker", (tester) async {
    final fakes = await pumpApp(
      tester,
      loggedIn: true,
      hasPassword: true,
      directory: FakeDirectoryRepository(
        workers: [listing(id: 'pema', name: 'Pema Dorji')],
        services: {'pema': [offers('pema', plumber)]},
      ),
    );
    await tapAndSettle(tester, 'Plumber');
    await tapAndSettle(tester, 'Pema Dorji');

    await tapAndSettle(tester, AppStrings.call);
    await tapAndSettle(tester, AppStrings.whatsapp);
    expect(fakes.contacts.recorded, [
      (workerId: 'pema', method: ContactMethod.call),
      (workerId: 'pema', method: ContactMethod.whatsapp),
    ]);
  });

  group('wording', () {
    test('uses what the database saved, with fallbacks for missing names', () {
      expect(title(NotificationTypes.reportNew, {'worker_name': 'Pema Dorji'}), 'New report about Pema Dorji');
      expect(title(NotificationTypes.workerResubmitted, {'name': ' '}), 'A worker asks to be checked again');
      expect(title(NotificationTypes.reviewUpdated, {'rating': 1}), 'A customer changed their rating to 1 star');
      expect(title('something_new'), AppStrings.appName);
    });

    test("a rejection or deactivation shows the admin's note when there is one", () {
      expect(AppStrings.notificationBody(NotificationTypes.workerRejected, {'note': 'Blurry CID.'}), 'Blurry CID.');
      expect(AppStrings.notificationBody(NotificationTypes.workerRejected, {'note': null}),
          AppStrings.rejectedMessage);
      expect(AppStrings.notificationBody(NotificationTypes.accountDeactivated, {'reason': null}),
          AppStrings.deactivatedMessage);
    });

    test('says how long ago', () {
      final now = DateTime(2026, 9, 29, 12);
      expect(AppStrings.timeAgo(now.subtract(const Duration(seconds: 20)), now: now), 'Just now');
      expect(AppStrings.timeAgo(now.subtract(const Duration(minutes: 5)), now: now), '5 min ago');
      expect(AppStrings.timeAgo(now.subtract(const Duration(hours: 1)), now: now), '1 hour ago');
      expect(AppStrings.timeAgo(now.subtract(const Duration(days: 3)), now: now), '3 days ago');
      expect(AppStrings.timeAgo(DateTime(2026, 9, 1), now: now), '1 Sep 2026');
    });
  });
}
