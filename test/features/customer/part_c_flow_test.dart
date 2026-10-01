import 'package:bhutan_services/core/constants/app_constants.dart';
import 'package:bhutan_services/core/constants/dzongkhags.dart';
import 'package:bhutan_services/core/strings/app_strings.dart';
import 'package:bhutan_services/shared/models/review.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/fakes.dart';

// Part C: a logged-in customer finds, contacts, reviews and reports workers.

FakeDirectoryRepository directory() => FakeDirectoryRepository(
      workers: [
        listing(id: 'pema', name: 'Pema Dorji', town: 'Changzamtog'),
        listing(id: 'karma', name: 'Karma Wangdi', dzongkhag: 'Paro', town: 'Bondey'),
        listing(id: 'sonam', name: 'Sonam Choden', town: 'Motithang'),
        listing(id: 'dechen', name: 'Dechen Wangmo', status: VerificationStatus.pending),
      ],
      services: {
        'pema': [offers('pema', plumber, price: 'Nu 500 per visit')],
        'karma': [offers('karma', plumber)],
        'sonam': [offers('sonam', electrician)],
        'dechen': [offers('dechen', plumber)],
      },
    );

final pemasReview = Review(
  id: 'review-0',
  workerId: 'pema',
  customerId: 'someone-else',
  rating: 5,
  comment: 'Came on time and fixed the leak.',
  createdAt: DateTime(2026, 9, 1),
);

Future<Fakes> openHome(WidgetTester tester) => pumpApp(
      tester,
      loggedIn: true,
      hasPassword: true,
      directory: directory(),
      reviews: FakeReviewRepository([pemasReview]),
    );

Future<void> openPemasDetails(WidgetTester tester) async {
  await tapAndSettle(tester, 'Plumber');
  await tapAndSettle(tester, 'Pema Dorji');
}

void main() {
  testWidgets('C1 shows the services and searches Thimphu until the customer picks a dzongkhag',
      (tester) async {
    await openHome(tester);

    expect(find.text(AppStrings.greeting('Test')), findsOneWidget);
    expect(find.text('Plumber'), findsOneWidget);
    expect(find.text('Electrician'), findsOneWidget);
    expect(find.text('Thimphu'), findsOneWidget);
  });

  testWidgets('C2 lists only workers offering the service in the chosen dzongkhag',
      (tester) async {
    await openHome(tester);

    await tapAndSettle(tester, 'Plumber');
    expect(find.text('Pema Dorji'), findsOneWidget);
    expect(find.text('Nu. 500 per visit'), findsOneWidget); // as typed: 'Nu 500 per visit'
    expect(find.text('Karma Wangdi'), findsNothing); // Paro
    expect(find.text('Sonam Choden'), findsNothing); // electrician
    expect(find.text('Dechen Wangmo'), findsNothing); // not approved yet

    await tapAndSettle(tester, 'Thimphu');
    await tapAndSettle(tester, 'Paro');
    expect(find.text('Karma Wangdi'), findsOneWidget);
    expect(find.text('Pema Dorji'), findsNothing);

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('selected_dzongkhag'), 'Paro');
  });

  testWidgets('C2 "All dzongkhags" lists workers from everywhere, and is remembered',
      (tester) async {
    await openHome(tester);

    await tapAndSettle(tester, 'Plumber');
    await tapAndSettle(tester, 'Thimphu');
    await tapAndSettle(tester, AppStrings.allDzongkhags);
    expect(find.text('Pema Dorji'), findsOneWidget);
    expect(find.text('Karma Wangdi'), findsOneWidget);
    expect(find.text('Dechen Wangmo'), findsNothing);

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('selected_dzongkhag'), kAllDzongkhags);
  });

  testWidgets('the dzongkhag list narrows as you type: a name, another spelling or a town', (tester) async {
    await openHome(tester);
    await tapAndSettle(tester, 'Thimphu'); // 'Your area'
    final typing = find.descendant(of: find.byType(BottomSheet), matching: find.byType(TextField));

    await tester.enterText(typing, 'phuents');
    await tester.pumpAndSettle();
    expect(find.text('Chhukha'), findsOneWidget);
    expect(find.text('Phuentsholing'), findsOneWidget); // why it's there
    expect(find.text('Paro'), findsNothing);

    await tester.enterText(typing, 'xyz');
    await tester.pumpAndSettle();
    expect(find.text(AppStrings.nothingMatches('xyz')), findsOneWidget);

    await tester.enterText(typing, 'wangdi');
    await tester.pumpAndSettle();
    await tapAndSettle(tester, 'Wangdue Phodrang');
    expect(find.text('Wangdue Phodrang'), findsOneWidget); // now 'Your area'
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('selected_dzongkhag'), 'Wangdue Phodrang');
  });

  testWidgets('C2 says so when there is nobody in that dzongkhag yet', (tester) async {
    await openHome(tester);

    await tapAndSettle(tester, 'Plumber');
    await tapAndSettle(tester, 'Thimphu');
    await tapAndSettle(tester, 'Gasa');
    expect(find.text(AppStrings.noWorkersYet('Plumber')), findsOneWidget);
  });

  testWidgets('the chosen dzongkhag is remembered after a restart', (tester) async {
    await pumpApp(
      tester,
      loggedIn: true,
      hasPassword: true,
      directory: directory(),
      savedSettings: {'selected_dzongkhag': 'Paro'},
    );
    expect(find.text('Paro'), findsOneWidget);

    await tapAndSettle(tester, 'Plumber');
    expect(find.text('Karma Wangdi'), findsOneWidget);
  });

  testWidgets('C3 shows services, reviews and the Call and WhatsApp buttons', (tester) async {
    await openHome(tester);
    await openPemasDetails(tester);

    expect(find.text('Pema Dorji'), findsOneWidget);
    expect(find.text(AppStrings.verified), findsOneWidget);
    expect(find.text('Changzamtog, Thimphu'), findsOneWidget);
    expect(find.text(AppStrings.call), findsOneWidget);
    expect(find.text(AppStrings.whatsapp), findsOneWidget);
    expect(find.text(AppStrings.adminCheck), findsNothing); // admins only

    await tester.dragUntilVisible(
        find.text(pemasReview.comment!), find.byType(Scrollable).first, const Offset(0, -250));
    expect(find.text('Nu. 500 per visit'), findsOneWidget); // as typed: 'Nu 500 per visit'
    expect(find.text(pemasReview.comment!), findsOneWidget);
  });

  testWidgets('C4 a customer rates a worker, then can edit the review', (tester) async {
    final fakes = await pumpApp(
      tester,
      loggedIn: true,
      hasPassword: true,
      directory: directory(),
      reviews: FakeReviewRepository([pemasReview]),
      contacted: {'pema'}, // only customers who got in touch can review
    );
    await openPemasDetails(tester);

    await scrollAndTap(tester, find.text(AppStrings.writeReview));
    await tapAndSettle(tester, AppStrings.postReview);
    expect(find.text(AppStrings.chooseRating), findsOneWidget);

    await tester.tap(find.byTooltip(AppStrings.starsLabel(4)));
    await tester.pump();
    expect(find.text(AppStrings.ratingWord(4)), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'Good work, fair price.');
    await tapAndSettle(tester, AppStrings.postReview);

    final mine = fakes.reviews.reviews.firstWhere((r) => r.customerId == me);
    expect((mine.rating, mine.comment), (4, 'Good work, fair price.'));
    expect(find.text(AppStrings.reviewSaved), findsOneWidget);

    await scrollAndTap(tester, find.text(AppStrings.editReview));
    expect(find.text(AppStrings.updateReview), findsOneWidget);
    expect(find.text('Good work, fair price.'), findsOneWidget);
  });

  testWidgets('C5 a customer reports a worker; "Something else" needs details', (tester) async {
    final fakes = await openHome(tester);
    await openPemasDetails(tester);

    await scrollAndTap(tester, find.text(AppStrings.reportWorker));
    await tapAndSettle(tester, AppStrings.sendReport);
    expect(find.text(AppStrings.chooseReason), findsOneWidget);

    await tapAndSettle(tester, AppStrings.reportReason('other'));
    await tapAndSettle(tester, AppStrings.sendReport);
    expect(find.text(AppStrings.reportDetailsNeeded), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'Asked for money before starting.');
    await tapAndSettle(tester, AppStrings.sendReport);
    expect(fakes.reports.reports.single,
        (workerId: 'pema', reason: 'other', details: 'Asked for money before starting.'));
    expect(find.text(AppStrings.reportSent), findsOneWidget);
  });
}
