import 'package:bhutan_services/core/constants/app_constants.dart';
import 'package:bhutan_services/core/strings/app_strings.dart';
import 'package:bhutan_services/shared/models/profile.dart';
import 'package:bhutan_services/shared/models/report.dart';
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

    testWidgets('admins cannot be deactivated or deleted', (tester) async {
      await openUsers(tester);

      await tapAndSettle(tester, 'Tshering Admin');
      expect(find.text(AppStrings.adminsCantBeDeactivated), findsOneWidget);
      expect(find.text(AppStrings.deactivateAccount), findsNothing);
      expect(find.text(AppStrings.deleteAccount), findsNothing);
      expect(find.text(AppStrings.editRoles), findsNothing);
    });

    /// Ticks or unticks [role] in the Edit roles dialog.
    Future<void> tapRole(WidgetTester tester, String role) async {
      await tester.tap(find.descendant(of: find.byType(AlertDialog), matching: find.text(AppStrings.roleLabel(role))));
      await tester.pumpAndSettle();
    }

    testWidgets('an admin gives a customer more roles; the main role follows', (tester) async {
      final fakes = await openUsers(tester);

      await tapAndSettle(tester, 'Karma Wangdi');
      await tapAndSettle(tester, AppStrings.editRoles);
      expect(find.text(AppStrings.rolesTitle('Karma Wangdi')), findsOneWidget);
      expect(find.text(AppStrings.mainRoleNote(UserRole.customer)), findsOneWidget);
      expect(tester.widget<FilledButton>(find.widgetWithText(FilledButton, AppStrings.save)).onPressed,
          isNull); // nothing changed yet

      await tapRole(tester, UserRole.player);
      await tapRole(tester, UserRole.worker);
      expect(find.text(AppStrings.mainRoleNote(UserRole.worker)), findsOneWidget);
      await tapAndSettle(tester, AppStrings.save);

      final change = fakes.admin.roleChanges.single;
      expect(change.userId, 'karma');
      expect(change.roles, {UserRole.customer, UserRole.player, UserRole.worker});
      expect(find.text(AppStrings.rolesSaved('Karma Wangdi')), findsOneWidget);
      expect(find.text(AppStrings.roleLabel(UserRole.worker)), findsOneWidget); // tag in the list
    });

    testWidgets('an account keeps at least one role', (tester) async {
      await openUsers(tester);
      await tapAndSettle(tester, 'Karma Wangdi');
      await tapAndSettle(tester, AppStrings.editRoles);

      await tapRole(tester, UserRole.customer); // untick the only one
      expect(find.text(AppStrings.pickARole), findsOneWidget);
      expect(tester.widget<FilledButton>(find.widgetWithText(FilledButton, AppStrings.save)).onPressed, isNull);
    });

    testWidgets("a ground manager's role is locked, and they can't be a worker too", (tester) async {
      const dorji = Profile(id: 'dorji', fullName: 'Dorji Manager', role: UserRole.groundManager,
          roles: [UserRole.groundManager, UserRole.customer]);
      await pumpApp(tester, role: UserRole.admin, loggedIn: true, directory: directory(), users: [dorji]);
      await tester.tap(find.byTooltip(AppStrings.settings));
      await tester.pumpAndSettle();
      await tapAndSettle(tester, AppStrings.users);
      await tapAndSettle(tester, 'Dorji Manager');
      await tapAndSettle(tester, AppStrings.editRoles);

      expect(find.text(AppStrings.workerNotWithManager), findsOneWidget);
      expect(find.text(AppStrings.roleHint(UserRole.groundManager)), findsOneWidget);
      expect(find.text(AppStrings.mainRoleNote(UserRole.groundManager)), findsOneWidget);
    });

    testWidgets('an admin deletes a user after confirming; Cancel keeps them', (tester) async {
      final fakes = await openUsers(tester);

      await tapAndSettle(tester, 'Karma Wangdi');
      await tapAndSettle(tester, AppStrings.deleteAccount);
      expect(find.text(AppStrings.deleteUserTitle('Karma Wangdi')), findsOneWidget);
      expect(find.text(AppStrings.deleteUserMessage(UserRole.customer)), findsOneWidget);
      await tapAndSettle(tester, AppStrings.cancel);
      expect(fakes.admin.deletedUsers, isEmpty);

      await tapAndSettle(tester, AppStrings.deleteAccount);
      await tapAndSettle(tester, AppStrings.deleteForGood);
      expect(fakes.admin.deletedUsers, ['karma']);
      expect(find.text(AppStrings.userDeleted('Karma Wangdi')), findsOneWidget);
      expect(find.text('karma@example.com'), findsNothing); // gone from the list
      expect(find.text('Tshering Admin'), findsOneWidget);
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

  group('reports', () {
    Report aboutPema({String status = ReportStatus.open}) => Report(
          id: 'report-1',
          workerId: 'pema',
          workerName: 'Pema Dorji',
          reporterName: 'Karma Wangdi',
          reporterEmail: 'karma@example.com',
          reason: 'overcharged',
          details: 'Asked Nu 2000 for a small job.',
          status: status,
          createdAt: DateTime.now().subtract(const Duration(minutes: 5)),
        );

    Future<Fakes> openReports(WidgetTester tester) async {
      final fakes = await pumpApp(tester,
          role: UserRole.admin, loggedIn: true, directory: directory(), reports: [aboutPema()]);
      await tester.tap(find.byTooltip(AppStrings.settings));
      await tester.pumpAndSettle();
      await tapAndSettle(tester, AppStrings.reports);
      return fakes;
    }

    testWidgets('an admin reads an open report and marks it reviewed', (tester) async {
      final fakes = await openReports(tester);
      expect(find.text(AppStrings.reportReason('overcharged')), findsOneWidget);
      expect(find.text('Asked Nu 2000 for a small job.'), findsOneWidget);
      expect(find.text('${AppStrings.reportedBy('Karma Wangdi')} · 5 min ago'), findsOneWidget);

      await tapAndSettle(tester, 'Pema Dorji');
      expect(find.text('karma@example.com'), findsOneWidget);
      await tapAndSettle(tester, AppStrings.markReviewed);

      expect(fakes.admin.reports.single.status, ReportStatus.reviewed);
      expect(find.text(AppStrings.reportStatusChanged(ReportStatus.reviewed)), findsOneWidget);
      expect(find.text(AppStrings.noReports(ReportStatus.open)), findsOneWidget);

      await tapAndSettle(tester, AppStrings.reportStatusLabel(ReportStatus.reviewed));
      expect(find.text('Pema Dorji'), findsOneWidget);
      await tapAndSettle(tester, 'Pema Dorji');
      await tapAndSettle(tester, AppStrings.closeReport);
      expect(fakes.admin.reports.single.status, ReportStatus.closed);
    });

    testWidgets("a report opens the worker's page, to deactivate them", (tester) async {
      await openReports(tester);

      await tapAndSettle(tester, 'Pema Dorji');
      await tapAndSettle(tester, AppStrings.openWorkerPage);
      expect(find.text(AppStrings.adminCheck), findsOneWidget);
    });

    testWidgets('the new-report notification opens Reports', (tester) async {
      await pumpApp(tester, role: UserRole.admin, loggedIn: true, directory: directory(), reports: [
        aboutPema(),
      ], notifications: [
        notice(NotificationTypes.reportNew,
            data: {'worker_id': 'pema', 'worker_name': 'Pema Dorji', 'reason': 'overcharged'}),
      ]);
      await tester.tap(find.byTooltip(AppStrings.notifications));
      await tester.pumpAndSettle();

      await tapAndSettle(tester, 'New report about Pema Dorji');
      expect(find.text(AppStrings.reports), findsOneWidget); // app bar
      expect(find.text('Asked Nu 2000 for a small job.'), findsOneWidget);
    });
  });
}
