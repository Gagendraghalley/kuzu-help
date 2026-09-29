import 'package:bhutan_services/core/constants/app_constants.dart';
import 'package:bhutan_services/core/strings/app_strings.dart';
import 'package:bhutan_services/shared/models/review.dart';
import 'package:bhutan_services/shared/models/service_category.dart';
import 'package:bhutan_services/shared/models/verification.dart';
import 'package:bhutan_services/shared/models/work_photo.dart';
import 'package:bhutan_services/shared/models/worker_profile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fakes.dart';

// Reviews only after getting in touch, workers' replies, 'Available now',
// search by name, saved workers, photos of past work, Dzongkha category names.

FakeDirectoryRepository directory() => FakeDirectoryRepository(
      workers: [
        listing(id: 'pema', name: 'Pema Dorji'),
        listing(id: 'tashi', name: 'Tashi Tshering', available: false),
        listing(id: 'karma', name: 'Karma Wangdi', dzongkhag: 'Paro'),
      ],
      services: {
        'pema': [offers('pema', plumber)],
        'tashi': [offers('tashi', plumber)],
        'karma': [offers('karma', plumber)],
      },
    );

Future<Fakes> openHome(WidgetTester tester, {List<String> saved = const []}) =>
    pumpApp(tester, loggedIn: true, hasPassword: true, directory: directory(), saved: saved);

/// An approved worker ([me]) on their dashboard, with one review.
Future<Fakes> openDashboard(WidgetTester tester, {Map<String, List<WorkPhoto>> photos = const {}}) => pumpApp(
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
      reviews: FakeReviewRepository([
        Review(
          id: 'review-1',
          workerId: me,
          customerId: 'customer-1',
          rating: 3,
          comment: 'Came late.',
          createdAt: DateTime(2026, 9, 1),
        ),
      ]),
      workPhotos: photos,
    );

WorkPhoto photo(String id) =>
    WorkPhoto(id: id, workerId: me, path: '$me/$id.jpg', url: 'https://example.com/$id.jpg');

void main() {
  testWidgets('a customer can review a worker only after getting in touch', (tester) async {
    final fakes = await openHome(tester);
    await tapAndSettle(tester, 'Plumber');
    await tapAndSettle(tester, 'Pema Dorji');

    await tester.dragUntilVisible(
        find.text(AppStrings.reviewAfterContact), find.byType(Scrollable).first, const Offset(0, -250));
    expect(find.text(AppStrings.writeReview), findsNothing);

    await tapAndSettle(tester, AppStrings.call); // the phone app can't open in tests
    expect(fakes.contacts.recorded.single, (workerId: 'pema', method: ContactMethod.call));
    expect(find.text(AppStrings.reviewAfterContact), findsNothing);
    expect(find.text(AppStrings.writeReview), findsOneWidget);
  });

  testWidgets('a worker replies to a review, and the reply shows under it', (tester) async {
    final fakes = await openDashboard(tester);

    await scrollAndTap(tester, find.text(AppStrings.reply));
    await tester.tap(find.widgetWithText(FilledButton, AppStrings.reply));
    await tester.pumpAndSettle();
    expect(find.text(AppStrings.replyNeeded), findsOneWidget);

    await tester.enterText(find.byType(TextField).last, 'Sorry, the road was closed.');
    await tester.tap(find.widgetWithText(FilledButton, AppStrings.reply));
    await tester.pumpAndSettle();

    expect(fakes.reviews.replies.single, (reviewId: 'review-1', reply: 'Sorry, the road was closed.'));
    expect(find.text(AppStrings.replySaved), findsOneWidget);
    expect(find.text(AppStrings.replyFromWorker), findsOneWidget);
    expect(find.text('Sorry, the road was closed.'), findsOneWidget);
    expect(find.text(AppStrings.editReply), findsOneWidget);
  });

  testWidgets('"Available now" leaves out workers who are busy', (tester) async {
    await openHome(tester);
    await tapAndSettle(tester, 'Plumber');
    expect(find.text('Tashi Tshering'), findsOneWidget);

    await tapAndSettle(tester, AppStrings.availableNow);
    expect(find.text('Pema Dorji'), findsOneWidget);
    expect(find.text('Tashi Tshering'), findsNothing);
  });

  testWidgets('search by name finds workers in any dzongkhag', (tester) async {
    await openHome(tester);

    await tapAndSettle(tester, AppStrings.searchWorkers);
    expect(find.text(AppStrings.typeToSearch), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'karma');
    await tester.pumpAndSettle();
    expect(find.text('Karma Wangdi'), findsOneWidget); // Paro, though Thimphu is chosen
    expect(find.text('Pema Dorji'), findsNothing);

    await tester.enterText(find.byType(TextField), 'zangmo');
    await tester.pumpAndSettle();
    expect(find.text(AppStrings.noWorkersNamed('zangmo')), findsOneWidget);
  });

  testWidgets('the heart saves a worker, who then shows under Saved workers', (tester) async {
    final fakes = await openHome(tester);
    await tapAndSettle(tester, AppStrings.savedWorkers);
    expect(find.text(AppStrings.noSavedWorkers), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();

    await tapAndSettle(tester, 'Plumber');
    await tapAndSettle(tester, 'Pema Dorji');
    await tester.tap(find.byTooltip(AppStrings.saveWorker));
    await tester.pumpAndSettle();
    expect(fakes.saved.saved, ['pema']);
    expect(find.text(AppStrings.workerSaved), findsOneWidget);
    expect(find.byTooltip(AppStrings.unsaveWorker), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tapAndSettle(tester, AppStrings.savedWorkers);
    expect(find.text('Pema Dorji'), findsOneWidget);
  });

  testWidgets("photos of past work show on the worker's page", (tester) async {
    await pumpApp(tester,
        loggedIn: true,
        hasPassword: true,
        directory: directory(),
        workPhotos: {
          'pema': [WorkPhoto(id: 'p1', workerId: 'pema', path: 'pema/p1.jpg', url: 'https://example.com/p1.jpg')],
        });
    await tapAndSettle(tester, 'Plumber');
    await tapAndSettle(tester, 'Pema Dorji');

    await tester.dragUntilVisible(
        find.text(AppStrings.workPhotos), find.byType(Scrollable).first, const Offset(0, -250));
    expect(find.text(AppStrings.workPhotos), findsOneWidget);
  });

  testWidgets('a worker removes a photo of their work', (tester) async {
    final fakes = await openDashboard(tester, photos: {me: [photo('a'), photo('b')]});

    await scrollAndTap(tester, find.text(AppStrings.yourWorkPhotos));
    expect(find.text(AppStrings.workPhotosHint(AppConstants.maxWorkPhotos)), findsOneWidget);
    expect(find.byTooltip(AppStrings.remove), findsNWidgets(2));

    await tester.tap(find.byTooltip(AppStrings.remove).first);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, AppStrings.remove));
    await tester.pumpAndSettle();
    expect(fakes.workPhotos.photos[me]!.map((p) => p.id), ['b']);
    expect(find.byTooltip(AppStrings.remove), findsOneWidget);
  });

  testWidgets('categories show their Dzongkha name once an admin fills it in', (tester) async {
    await pumpApp(tester,
        loggedIn: true,
        hasPassword: true,
        directory: FakeDirectoryRepository(categories: const [
          ServiceCategory(id: 'cat-plumber', name: 'Plumber', nameDz: 'Plumber in Dzongkha', isActive: true),
          electrician,
        ]));
    expect(find.text('Plumber in Dzongkha'), findsOneWidget);
    expect(find.text('Electrician'), findsOneWidget);
  });
}
