import 'package:bhutan_services/core/constants/app_constants.dart';
import 'package:bhutan_services/core/strings/app_strings.dart';
import 'package:bhutan_services/shared/models/app_notification.dart';
import 'package:bhutan_services/shared/models/job_request.dart';
import 'package:bhutan_services/shared/models/verification.dart';
import 'package:bhutan_services/shared/models/worker_profile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fakes.dart';

// Job requests: customers send them; workers accept or decline; either marks
// an accepted job done; customers can cancel until then.

FakeDirectoryRepository directory({bool pemaAvailable = true}) => FakeDirectoryRepository(
      workers: [listing(id: 'pema', name: 'Pema Dorji', available: pemaAvailable)],
      services: {'pema': [offers('pema', plumber)]},
    );

JobRequest job({
  String status = JobStatus.pending,
  String customerId = me,
  String workerId = 'pema',
  String? note,
}) =>
    JobRequest(
      id: 'job-1',
      customerId: customerId,
      workerId: workerId,
      customerName: 'Karma Wangdi',
      workerName: 'Pema Dorji',
      categoryName: 'Plumber',
      categoryIcon: 'plumber',
      description: 'Kitchen tap leaking',
      whenNeeded: 'Tomorrow morning',
      address: 'Changzamtog, Thimphu',
      contactPhone: '+97517999999',
      status: status,
      workerNote: note,
      createdAt: DateTime.now().subtract(const Duration(hours: 2)),
    );

Future<Fakes> openAsCustomer(WidgetTester tester, {List<JobRequest> jobs = const [], bool pemaAvailable = true}) =>
    pumpApp(tester,
        loggedIn: true, hasPassword: true, directory: directory(pemaAvailable: pemaAvailable), jobs: jobs);

/// An approved worker ([me]) on their dashboard.
Future<Fakes> openAsWorker(
  WidgetTester tester, {
  List<JobRequest> jobs = const [],
  List<AppNotification> notifications = const [],
}) =>
    pumpApp(
      tester,
      role: UserRole.worker,
      loggedIn: true,
      hasPassword: true,
      worker: FakeWorkerRepository(
        workerProfile: const WorkerProfile(
          id: me,
          yearsExperience: 5,
          whatsappNumber: '+97517123456',
          isAvailable: true,
          verificationStatus: VerificationStatus.approved,
        ),
        services: [offers(me, plumber)],
        verification: Verification(workerId: me, cidPath: '$me/cid.jpg', submittedAt: DateTime(2026, 9, 1)),
      ),
      directory: FakeDirectoryRepository(
        workers: [listing(id: me, name: 'Test')],
        services: {me: [offers(me, plumber)]},
      ),
      jobs: jobs,
      notifications: notifications,
    );

void main() {
  testWidgets('a customer sends a job request, and the worker page then links to it', (tester) async {
    final fakes = await openAsCustomer(tester);
    await tapAndSettle(tester, 'Plumber');
    await tapAndSettle(tester, 'Pema Dorji');

    await tapAndSettle(tester, AppStrings.requestJob);
    expect(find.text(AppStrings.jobRequestIntro('Pema Dorji')), findsOneWidget);
    await scrollAndTap(tester, find.text(AppStrings.sendRequest));
    expect(find.text(AppStrings.describeJob), findsOneWidget);
    expect(find.text(AppStrings.enterAddress), findsOneWidget);
    expect(find.text(AppStrings.invalidMobile), findsOneWidget);

    await enterField(tester, AppStrings.jobDescription, 'Kitchen tap leaking');
    await enterField(tester, AppStrings.jobAddress, 'Changzamtog, Thimphu');
    await enterField(tester, AppStrings.jobWhen, 'Tomorrow morning');
    await enterField(tester, AppStrings.jobPhone, '17999999');
    await scrollAndTap(tester, find.text(AppStrings.sendRequest));

    final sent = fakes.jobs.jobs.single;
    expect((sent.workerId, sent.description, sent.address, sent.whenNeeded, sent.contactPhone),
        ('pema', 'Kitchen tap leaking', 'Changzamtog, Thimphu', 'Tomorrow morning', '+97517999999'));
    expect(find.text(AppStrings.jobRequestSent), findsOneWidget);
    expect(find.text(AppStrings.seeYourRequest), findsOneWidget);
    expect(find.text(AppStrings.requestJob), findsNothing); // one open request per worker
  });

  testWidgets('workers who are not taking work get no requests', (tester) async {
    await openAsCustomer(tester, pemaAvailable: false);
    await tapAndSettle(tester, 'Plumber');
    await tapAndSettle(tester, 'Pema Dorji');

    expect(find.text(AppStrings.notAvailableNow), findsOneWidget);
    expect(find.text(AppStrings.requestJob), findsNothing);
  });

  testWidgets('a customer follows their request and cancels it', (tester) async {
    final fakes = await openAsCustomer(tester, jobs: [job()]);

    await tapAndSettle(tester, AppStrings.myJobRequests);
    expect(find.text(AppStrings.jobTo('Pema Dorji')), findsOneWidget);
    expect(find.text(AppStrings.jobStatusLabel(JobStatus.pending)), findsOneWidget);

    await tapAndSettle(tester, AppStrings.jobTo('Pema Dorji'));
    expect(find.textContaining('Changzamtog, Thimphu', findRichText: true), findsOneWidget);
    await tapAndSettle(tester, AppStrings.cancelRequest);
    await tester.tap(find.widgetWithText(FilledButton, AppStrings.cancelRequest));
    await tester.pumpAndSettle();

    expect(fakes.jobs.jobs.single.status, JobStatus.cancelled);
    expect(find.text(AppStrings.jobStatusChanged(JobStatus.cancelled)), findsOneWidget);
    expect(find.text(AppStrings.noJobs(active: true, asWorker: false)), findsOneWidget);

    await tapAndSettle(tester, AppStrings.pastJobs);
    expect(find.text(AppStrings.jobStatusLabel(JobStatus.cancelled)), findsOneWidget);
  });

  testWidgets('a worker accepts a new request with a note, then marks it done', (tester) async {
    final fakes = await openAsWorker(tester, jobs: [job(customerId: 'karma', workerId: me)]);
    expect(find.text(AppStrings.newJobRequests(1)), findsOneWidget);

    await tapAndSettle(tester, AppStrings.jobRequests);
    await tapAndSettle(tester, AppStrings.jobFrom('Karma Wangdi'));
    expect(find.text(AppStrings.call), findsOneWidget); // to reach the customer
    await tapAndSettle(tester, AppStrings.acceptJob);
    await tester.enterText(find.byType(TextField), 'I can come at 9am.');
    await tester.tap(find.widgetWithText(FilledButton, AppStrings.acceptJob).last);
    await tester.pumpAndSettle();

    expect(fakes.jobs.jobs.single.status, JobStatus.accepted);
    expect(fakes.jobs.jobs.single.workerNote, 'I can come at 9am.');
    expect(find.text(AppStrings.jobStatusChanged(JobStatus.accepted)), findsOneWidget);

    await tapAndSettle(tester, AppStrings.jobFrom('Karma Wangdi'));
    expect(find.text('I can come at 9am.'), findsOneWidget);
    await tapAndSettle(tester, AppStrings.markDone);
    await tester.tap(find.widgetWithText(FilledButton, AppStrings.markDone).last);
    await tester.pumpAndSettle();
    expect(fakes.jobs.jobs.single.status, JobStatus.completed);
  });

  testWidgets('a worker declines a request', (tester) async {
    final fakes = await openAsWorker(tester, jobs: [job(customerId: 'karma', workerId: me)]);
    await tapAndSettle(tester, AppStrings.jobRequests);
    await tapAndSettle(tester, AppStrings.jobFrom('Karma Wangdi'));

    await tapAndSettle(tester, AppStrings.declineJob);
    await tester.tap(find.widgetWithText(FilledButton, AppStrings.declineJob)); // the reason is optional
    await tester.pumpAndSettle();
    expect(fakes.jobs.jobs.single.status, JobStatus.declined);
  });

  testWidgets('a done job lets the customer write a review', (tester) async {
    await openAsCustomer(tester, jobs: [job(status: JobStatus.completed)]);
    await tapAndSettle(tester, AppStrings.myJobRequests);
    await tapAndSettle(tester, AppStrings.pastJobs);
    await tapAndSettle(tester, AppStrings.jobTo('Pema Dorji'));

    await tapAndSettle(tester, AppStrings.writeReview);
    expect(find.text(AppStrings.howWasTheWork), findsOneWidget);
  });

  testWidgets('the new-job notification opens Job requests', (tester) async {
    await openAsWorker(tester, jobs: [
      job(customerId: 'karma', workerId: me),
    ], notifications: [
      notice(NotificationTypes.jobNew, data: {'customer_name': 'Karma Wangdi', 'category': 'Plumber'}),
    ]);
    await tester.tap(find.byTooltip(AppStrings.notifications));
    await tester.pumpAndSettle();
    expect(find.text('Plumber · Tap to see the job and reply.'), findsOneWidget);

    await tapAndSettle(tester, 'New job request from Karma Wangdi');
    expect(find.text(AppStrings.jobFrom('Karma Wangdi')), findsOneWidget);
  });
}
