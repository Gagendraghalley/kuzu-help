import 'package:bhutan_services/core/constants/app_constants.dart';
import 'package:bhutan_services/core/strings/app_strings.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fakes.dart';

// Part D: settings, edit profile, log out, delete account.

Future<Fakes> openSettings(WidgetTester tester) async {
  final fakes = await pumpApp(tester, loggedIn: true, hasPassword: true);
  await tester.tap(find.byTooltip(AppStrings.settings));
  await tester.pumpAndSettle();
  return fakes;
}

/// The confirm button in the dialog (the list item has the same words).
Future<void> confirmDialog(WidgetTester tester, String label) async {
  await tester.tap(find.widgetWithText(FilledButton, label));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('Settings shows who is logged in', (tester) async {
    await openSettings(tester);

    expect(find.text('Test'), findsOneWidget);
    expect(find.text('test@example.com'), findsOneWidget);
    expect(find.text(AppStrings.roleLabel(UserRole.customer)), findsOneWidget);
    expect(find.text(AppStrings.becomeWorker), findsOneWidget);
  });

  testWidgets('D1 edit profile saves the name and location', (tester) async {
    final fakes = await openSettings(tester);

    await tapAndSettle(tester, AppStrings.editProfile);
    await enterField(tester, AppStrings.name, 'Tashi Dema');
    await enterField(tester, AppStrings.town, 'Lobesa');
    await tapAndSettle(tester, AppStrings.save);

    expect(fakes.profile.profile.fullName, 'Tashi Dema');
    expect(fakes.profile.profile.town, 'Lobesa');
    expect(find.text(AppStrings.profileSaved), findsOneWidget);
    expect(find.text('Tashi Dema'), findsOneWidget); // Settings shows the change
  });

  testWidgets('Change password saves the new one and goes back to Settings', (tester) async {
    final fakes = await openSettings(tester);

    await tapAndSettle(tester, AppStrings.changePassword);
    expect(find.text(AppStrings.changePasswordHint), findsOneWidget);
    await enterField(tester, AppStrings.password, 'new-druk-2026');
    await enterField(tester, AppStrings.confirmPassword, 'new-druk-2026');
    await tapAndSettle(tester, AppStrings.savePassword);

    expect(fakes.auth.savedPassword, 'new-druk-2026');
    expect(find.text(AppStrings.passwordChanged), findsOneWidget);
    expect(find.text(AppStrings.account), findsOneWidget); // back on Settings
    expect(fakes.auth.isLoggedIn, isTrue);
  });

  testWidgets('log out asks first, then returns to Welcome', (tester) async {
    final fakes = await openSettings(tester);

    await tapAndSettle(tester, AppStrings.logout);
    await tapAndSettle(tester, AppStrings.cancel);
    expect(fakes.auth.isLoggedIn, isTrue);

    await tapAndSettle(tester, AppStrings.logout);
    await confirmDialog(tester, AppStrings.logout);
    expect(fakes.auth.isLoggedIn, isFalse);
    expect(find.text(AppStrings.needService), findsOneWidget);
  });

  testWidgets('users cannot delete their own account, or reach admin tools', (tester) async {
    await openSettings(tester);

    expect(find.textContaining('Delete'), findsNothing);
    expect(find.text(AppStrings.users), findsNothing);
    expect(find.text(AppStrings.workersAwaitingApproval), findsNothing);
  });

  testWidgets('a worker can stop offering services and becomes a customer', (tester) async {
    final fakes = await pumpApp(tester, role: UserRole.worker, loggedIn: true, hasPassword: true);
    // New workers start on profile setup (B1), which has a way out too.
    await scrollAndTap(tester, find.text(AppStrings.onlyWantToFindWorkers));
    expect(find.text(AppStrings.stopOfferingServicesMessage), findsOneWidget);
    await confirmDialog(tester, AppStrings.continueLabel);

    expect(fakes.profile.profile.role, UserRole.customer);
    expect(find.text(AppStrings.whatDoYouNeed), findsOneWidget);
  });

  testWidgets('admins cannot switch to customer or worker', (tester) async {
    await pumpApp(tester, role: UserRole.admin, loggedIn: true);
    await tester.tap(find.byTooltip(AppStrings.settings));
    await tester.pumpAndSettle();

    expect(find.text(AppStrings.becomeWorker), findsNothing);
    expect(find.text(AppStrings.stopOfferingServices), findsNothing);
  });

  testWidgets('a customer becomes a worker and goes to worker profile setup', (tester) async {
    final fakes = await openSettings(tester);

    await tapAndSettle(tester, AppStrings.becomeWorker);
    await confirmDialog(tester, AppStrings.continueLabel);

    expect(fakes.profile.profile.role, UserRole.worker);
    expect(find.text(AppStrings.workerProfileTitle), findsOneWidget);
  });
}
