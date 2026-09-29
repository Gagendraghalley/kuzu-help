import 'package:bhutan_services/core/constants/app_constants.dart';
import 'package:bhutan_services/core/strings/app_strings.dart';
import 'package:bhutan_services/shared/models/profile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fakes.dart';

// Phase 5: an admin finds workers awaiting approval and approves or rejects them.

FakeDirectoryRepository directory() => FakeDirectoryRepository(
      workers: [
        listing(id: 'pema', name: 'Pema Dorji'),
        listing(id: 'dechen', name: 'Dechen Wangmo', status: VerificationStatus.pending),
      ],
      services: {
        'pema': [offers('pema', plumber)],
        'dechen': [offers('dechen', plumber)],
      },
    );

Future<Fakes> openDechenAsAdmin(WidgetTester tester) async {
  final fakes = await pumpApp(tester, role: UserRole.admin, loggedIn: true, directory: directory());
  await tapAndSettle(tester, 'Plumber');
  await tapAndSettle(tester, 'Dechen Wangmo');
  return fakes;
}

void main() {
  testWidgets('admins see workers awaiting approval in the lists, marked as such', (tester) async {
    await pumpApp(tester, role: UserRole.admin, loggedIn: true, directory: directory());

    await tapAndSettle(tester, 'Plumber');
    expect(find.text('Pema Dorji'), findsOneWidget);
    expect(find.text('Dechen Wangmo'), findsOneWidget);
    expect(find.text(AppStrings.awaitingApproval), findsOneWidget);
  });

  testWidgets('an admin approves a worker, who then shows as Verified', (tester) async {
    final fakes = await openDechenAsAdmin(tester);
    expect(find.text(AppStrings.adminPendingHint), findsOneWidget);
    expect(find.text(AppStrings.writeReview), findsNothing);

    await tapAndSettle(tester, AppStrings.approve);
    expect(fakes.admin.decisions.single, (workerId: 'dechen', status: VerificationStatus.approved, note: null));
    expect(find.text(AppStrings.workerApproved('Dechen Wangmo')), findsOneWidget);
    expect(find.text(AppStrings.verified), findsOneWidget);
    expect(find.text(AppStrings.adminApprovedHint), findsOneWidget);
    expect(find.text(AppStrings.approve), findsNothing);
  });

  testWidgets('rejecting asks what the worker should fix', (tester) async {
    final fakes = await openDechenAsAdmin(tester);

    await tapAndSettle(tester, AppStrings.reject);
    expect(find.text(AppStrings.rejectTitle), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, AppStrings.reject));
    await tester.pumpAndSettle();
    expect(find.text(AppStrings.rejectNoteNeeded), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'Your CID photo is blurry.');
    await tester.tap(find.widgetWithText(FilledButton, AppStrings.reject));
    await tester.pumpAndSettle();
    expect(fakes.admin.decisions.single,
        (workerId: 'dechen', status: VerificationStatus.rejected, note: 'Your CID photo is blurry.'));
    expect(find.text(AppStrings.notApproved), findsOneWidget);
    expect(find.text(AppStrings.adminRejectedHint), findsOneWidget);
  });

  testWidgets('Settings lists the workers awaiting approval', (tester) async {
    await pumpApp(tester, role: UserRole.admin, loggedIn: true, directory: directory());
    await tester.tap(find.byTooltip(AppStrings.settings));
    await tester.pumpAndSettle();

    await tapAndSettle(tester, AppStrings.workersAwaitingApproval);
    expect(find.text('Dechen Wangmo'), findsOneWidget);
    expect(find.text('Pema Dorji'), findsNothing);

    await tapAndSettle(tester, 'Dechen Wangmo');
    expect(find.text(AppStrings.adminCheck), findsOneWidget);
  });

  group('deactivating (blacklisting)', () {
    const karma = Profile(id: 'karma', fullName: 'Karma Wangdi', role: UserRole.customer, email: 'karma@example.com');
    const boss = Profile(id: 'boss', fullName: 'Tshering Admin', role: UserRole.admin, email: 'boss@example.com');

    Future<Fakes> openUsers(WidgetTester tester) async {
      final fakes = await pumpApp(tester,
          role: UserRole.admin, loggedIn: true, directory: directory(), users: [karma, boss]);
      await tester.tap(find.byTooltip(AppStrings.settings));
      await tester.pumpAndSettle();
      await tapAndSettle(tester, AppStrings.users);
      return fakes;
    }

    testWidgets('an admin finds a user and deactivates them with a reason', (tester) async {
      final fakes = await openUsers(tester);

      await tester.enterText(find.byType(TextField), 'karma');
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pumpAndSettle();
      expect(find.text('Tshering Admin'), findsNothing);

      await tapAndSettle(tester, 'Karma Wangdi');
      await tapAndSettle(tester, AppStrings.deactivateAccount);
      await tester.enterText(find.byType(TextField).last, 'Fake reviews.');
      await tester.tap(find.widgetWithText(FilledButton, AppStrings.deactivate));
      await tester.pumpAndSettle();

      expect(fakes.admin.activations.single, (userId: 'karma', active: false, reason: 'Fake reviews.'));
      expect(find.text(AppStrings.userDeactivated('Karma Wangdi')), findsOneWidget);
      expect(find.text(AppStrings.deactivated), findsOneWidget); // badge in the list

      await tapAndSettle(tester, 'Karma Wangdi');
      await tapAndSettle(tester, AppStrings.reactivateAccount);
      expect(fakes.admin.activations.last, (userId: 'karma', active: true, reason: null));
    });

    testWidgets('admins cannot be deactivated', (tester) async {
      await openUsers(tester);

      await tapAndSettle(tester, 'Tshering Admin');
      expect(find.text(AppStrings.adminsCantBeDeactivated), findsOneWidget);
      expect(find.text(AppStrings.deactivateAccount), findsNothing);
    });

    testWidgets("a worker is deactivated from their page's Admin check", (tester) async {
      final fakes = await openDechenAsAdmin(tester);

      await scrollAndTap(tester, find.text(AppStrings.deactivateAccount));
      await tester.tap(find.widgetWithText(FilledButton, AppStrings.deactivate)); // reason is optional
      await tester.pumpAndSettle();

      expect(fakes.admin.activations.single, (userId: 'dechen', active: false, reason: ''));
      // The card is above the part of the page scrolled to while tapping.
      expect(find.text(AppStrings.deactivatedWorkerHint, skipOffstage: false), findsOneWidget);
      expect(find.text(AppStrings.reactivateAccount, skipOffstage: false), findsOneWidget);
    });

    testWidgets('a deactivated user only sees why, and can only log out', (tester) async {
      final fakes = await pumpApp(tester,
          loggedIn: true, hasPassword: true, active: false, deactivatedReason: 'Fake reviews.');

      expect(find.text(AppStrings.deactivatedTitle), findsOneWidget);
      expect(find.text('Fake reviews.'), findsOneWidget);
      expect(find.text(AppStrings.whatDoYouNeed), findsNothing);

      await tapAndSettle(tester, AppStrings.logout);
      expect(fakes.auth.isLoggedIn, isFalse);
      expect(find.text(AppStrings.needService), findsOneWidget);
    });

    testWidgets('deactivation comes before setting a password', (tester) async {
      await pumpApp(tester, loggedIn: true, active: false);
      expect(find.text(AppStrings.deactivatedTitle), findsOneWidget);
      expect(find.text(AppStrings.createPasswordTitle), findsNothing);
    });
  });
}
