import 'package:bhutan_services/core/constants/app_constants.dart';
import 'package:bhutan_services/core/strings/app_strings.dart';
import 'package:bhutan_services/shared/models/review.dart';
import 'package:bhutan_services/shared/models/verification.dart';
import 'package:bhutan_services/shared/models/worker_profile.dart';
import 'package:bhutan_services/shared/widgets/dzongkhag_field.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fakes.dart';

// Part B: a worker sets up their profile, waits for approval and runs their dashboard.

WorkerProfile workerProfile(String status, {String? adminNotes}) => WorkerProfile(
      id: me,
      yearsExperience: 5,
      whatsappNumber: '+97517123456',
      isAvailable: true,
      verificationStatus: status,
      adminNotes: adminNotes,
    );

/// A worker who has sent everything, now [status].
FakeWorkerRepository sentEverything(String status, {String? adminNotes}) => FakeWorkerRepository(
      workerProfile: workerProfile(status, adminNotes: adminNotes),
      services: [offers(me, plumber)],
      verification: Verification(workerId: me, cidPath: '$me/cid.jpg', submittedAt: DateTime(2026, 9, 1)),
    );

void main() {
  testWidgets('B1 -> B2 -> B3: a new worker fills in their profile and services', (tester) async {
    final fakes = await pumpApp(tester, role: UserRole.worker, loggedIn: true, hasPassword: true);
    expect(find.text(AppStrings.workerProfileTitle), findsOneWidget);
    expect(find.text(AppStrings.setupStep(1, 3)), findsOneWidget);

    // B1: the number, dzongkhag and years are checked before saving.
    await scrollAndTap(tester, find.text(AppStrings.saveAndContinue));
    expect(find.text(AppStrings.invalidYears), findsOneWidget);
    expect(fakes.worker.workerProfile, isNull);

    await enterField(tester, AppStrings.mobileNumber, '17123456');
    await enterField(tester, AppStrings.yearsExperience, '8');
    await scrollAndTap(tester, find.byType(DzongkhagField));
    await tester.tap(find.text('Chhukha').last);
    await tester.pumpAndSettle();
    await scrollAndTap(tester, find.text(AppStrings.saveAndContinue));

    expect(fakes.worker.workerProfile?.whatsappNumber, '+97517123456');
    expect(fakes.worker.workerProfile?.yearsExperience, 8);
    expect(fakes.profile.profile.dzongkhag, 'Chhukha');

    // B2: at least one service, with an optional price.
    expect(find.text(AppStrings.setupStep(2, 3)), findsOneWidget);
    await scrollAndTap(tester, find.text(AppStrings.saveAndContinue));
    expect(find.text(AppStrings.chooseOneService), findsOneWidget);

    await tapAndSettle(tester, 'Plumber');
    await enterField(tester, AppStrings.priceNote, 'Nu 500 per visit');
    await scrollAndTap(tester, find.text(AppStrings.saveAndContinue));
    expect(fakes.worker.services.single.priceNote, 'Nu 500 per visit');

    // B3: a CID photo is required.
    expect(find.text(AppStrings.setupStep(3, 3)), findsOneWidget);
    await scrollAndTap(tester, find.text(AppStrings.sendForChecking));
    expect(find.text(AppStrings.addCidPhoto), findsOneWidget);
    expect(fakes.worker.verificationsSent, 0);
  });

  testWidgets('B1 checks the mobile number', (tester) async {
    await pumpApp(tester, role: UserRole.worker, loggedIn: true, hasPassword: true);

    await enterField(tester, AppStrings.mobileNumber, '12345');
    await scrollAndTap(tester, find.text(AppStrings.saveAndContinue));
    await tester.dragUntilVisible(
        find.text(AppStrings.invalidMobile), find.byType(Scrollable).first, const Offset(0, 250));
    expect(find.text(AppStrings.invalidMobile), findsOneWidget);
  });

  testWidgets('B4 pending: explains the wait and offers edits', (tester) async {
    await pumpApp(tester,
        role: UserRole.worker,
        loggedIn: true,
        hasPassword: true,
        worker: sentEverything(VerificationStatus.pending));

    expect(find.text(AppStrings.pendingTitle), findsOneWidget);
    expect(find.text(AppStrings.pendingMessage), findsOneWidget);
    expect(find.text(AppStrings.checkAgain), findsOneWidget);
  });

  testWidgets('B4 rejected: shows the team note; the worker sends new documents and asks again',
      (tester) async {
    final fakes = await pumpApp(tester,
        role: UserRole.worker,
        loggedIn: true,
        hasPassword: true,
        worker: sentEverything(VerificationStatus.rejected, adminNotes: 'Your CID photo is blurry.'));

    expect(find.text(AppStrings.rejectedTitle), findsOneWidget);
    expect(find.text('Your CID photo is blurry.'), findsOneWidget);

    // B3 opens to edit: the CID already sent counts, but consent is needed again.
    await scrollAndTap(tester, find.text(AppStrings.updateDocuments));
    expect(find.text(AppStrings.setupStep(3, 3)), findsNothing);
    expect(find.text(AppStrings.alreadySent), findsOneWidget);
    await scrollAndTap(tester, find.text(AppStrings.save));
    expect(find.text(AppStrings.consentNeeded), findsOneWidget);

    await scrollAndTap(tester, find.text(AppStrings.consent));
    await scrollAndTap(tester, find.text(AppStrings.save));
    expect(fakes.worker.verificationsSent, 1);
    expect(find.text(AppStrings.rejectedTitle), findsOneWidget); // back on B4

    await tester.pump(const Duration(seconds: 5)); // the 'Saved' message covers the button
    await tester.pumpAndSettle();
    await scrollAndTap(tester, find.text(AppStrings.sendAgain));
    expect(fakes.worker.reviewRequests, 1);
    expect(find.text(AppStrings.pendingTitle), findsOneWidget);
  });

  testWidgets('B5: an approved worker sees their rating and can turn availability off',
      (tester) async {
    final fakes = await pumpApp(
      tester,
      role: UserRole.worker,
      loggedIn: true,
      hasPassword: true,
      worker: sentEverything(VerificationStatus.approved),
      directory: FakeDirectoryRepository(
        workers: [listing(id: me, name: 'Test', rating: 4.7, reviewCount: 3)],
        services: {me: [offers(me, plumber, price: 'Nu 500 per visit')]},
      ),
      reviews: FakeReviewRepository([
        Review(
          id: 'review-0',
          workerId: me,
          customerId: 'customer-1',
          rating: 5,
          comment: 'Very helpful.',
          createdAt: DateTime(2026, 9, 1),
        ),
      ]),
    );

    expect(find.text(AppStrings.greeting('Test')), findsOneWidget);
    expect(find.text('4.7'), findsOneWidget);
    expect(find.text(AppStrings.availableForWork), findsOneWidget);

    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();
    expect(fakes.worker.availabilityChanges, [false]);
    expect(find.text(AppStrings.notAvailable), findsOneWidget);

    await tester.dragUntilVisible(
        find.text('Very helpful.'), find.byType(Scrollable).first, const Offset(0, -250));
    expect(find.text('Very helpful.'), findsOneWidget);
  });

  testWidgets("an approved worker's Settings has no role switching", (tester) async {
    final fakes = await pumpApp(
      tester,
      role: UserRole.worker,
      loggedIn: true,
      hasPassword: true,
      worker: sentEverything(VerificationStatus.approved),
      directory: FakeDirectoryRepository(workers: [listing(id: me, name: 'Test')]),
    );
    await tester.tap(find.byTooltip(AppStrings.settings));
    await tester.pumpAndSettle();

    expect(find.text(AppStrings.myServices), findsOneWidget); // their worker settings stay
    expect(find.text(AppStrings.stopOfferingServices), findsNothing);
    expect(find.text(AppStrings.addService(UserRole.player)), findsNothing);
    expect(fakes.profile.profile.role, UserRole.worker);
  });

  testWidgets('B5 -> B2: services open to edit and go back when saved', (tester) async {
    final fakes = await pumpApp(
      tester,
      role: UserRole.worker,
      loggedIn: true,
      hasPassword: true,
      worker: sentEverything(VerificationStatus.approved),
      directory: FakeDirectoryRepository(
        workers: [listing(id: me, name: 'Test')],
        services: {me: [offers(me, plumber)]},
      ),
    );

    await tapAndSettle(tester, AppStrings.edit);
    expect(find.text(AppStrings.servicesTitle), findsOneWidget);
    expect(find.text(AppStrings.setupStep(2, 3)), findsNothing);

    await tapAndSettle(tester, 'Electrician');
    await scrollAndTap(tester, find.text(AppStrings.save));
    expect(fakes.worker.services.map((s) => s.categoryId), {plumber.id, electrician.id});
    expect(find.text(AppStrings.availableForWork), findsOneWidget); // back on B5
  });
}
