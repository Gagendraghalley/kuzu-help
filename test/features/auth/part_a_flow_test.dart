import 'package:bhutan_services/core/constants/app_constants.dart';
import 'package:bhutan_services/core/strings/app_strings.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fakes.dart';

// Part A end to end, with Supabase replaced by fakes.

/// Types into the six code boxes (the only plain TextField on that screen).
Future<void> enterCode(WidgetTester tester, String code) async {
  await tester.enterText(find.byType(TextField), code);
  await tester.pumpAndSettle();
}

/// A5: types the password twice and saves it.
Future<void> setPassword(WidgetTester tester, String password) async {
  await enterField(tester, AppStrings.password, password);
  await enterField(tester, AppStrings.confirmPassword, password);
  await tapAndSettle(tester, AppStrings.savePassword);
}

/// The Log in button, on Welcome or on the log in screen (whose title says
/// 'Log in' too).
Future<void> tapLogIn(WidgetTester tester) async {
  await tester.tap(find.widgetWithText(FilledButton, AppStrings.logIn));
  await tester.pumpAndSettle();
}

/// A2 -> A3 -> A4 as a new customer.
Future<void> signUpUntilCode(WidgetTester tester) async {
  await tapAndSettle(tester, AppStrings.needService);
  await enterField(tester, AppStrings.name, 'Pema Dorji');
  await enterField(tester, AppStrings.email, 'pema@example.com');
  await tapAndSettle(tester, AppStrings.sendCode);
}

/// C1 and B1 are where customers and new workers start.
final customerHome = find.text(AppStrings.whatDoYouNeed);
final workerSetup = find.text(AppStrings.workerProfileTitle);

void main() {
  testWidgets('A1 -> A2: logged-out users see Welcome: create an account, or log in',
      (tester) async {
    await pumpApp(tester);
    expect(find.text(AppStrings.newToKuzuHelp), findsOneWidget);
    expect(find.text(AppStrings.needService), findsOneWidget);
    expect(find.text(AppStrings.offerService), findsOneWidget);
    expect(find.text(AppStrings.alreadyHaveAccount), findsOneWidget);
    expect(find.widgetWithText(FilledButton, AppStrings.logIn), findsOneWidget);
  });

  testWidgets('signing up with a registered email says so, and offers to log in instead',
      (tester) async {
    final auth = (await pumpApp(tester, hasPassword: true)).auth;

    await tapAndSettle(tester, AppStrings.offerService);
    expect(find.text(AppStrings.signingUpAs(UserRole.worker)), findsOneWidget);
    await enterField(tester, AppStrings.name, 'Dorji');
    await enterField(tester, AppStrings.email, FakeAuthRepository.registeredEmail);
    await tapAndSettle(tester, AppStrings.sendCode);

    expect(find.text(AppStrings.alreadyRegisteredTitle), findsOneWidget);
    expect(find.text(AppStrings.alreadyRegisteredWorkerTip), findsOneWidget);
    expect(auth.sentCodes, isEmpty); // not quietly logged in with the old role

    // 'Log in instead' keeps the email.
    await scrollAndTap(tester, find.text(AppStrings.logInInstead));
    expect(find.text(AppStrings.logInHint), findsOneWidget);
    await enterField(tester, AppStrings.password, FakeAuthRepository.correctPassword);
    await tapLogIn(tester);
    expect(auth.passwordLogIns, [FakeAuthRepository.registeredEmail]);
    expect(customerHome, findsOneWidget);
  });

  testWidgets('logging in with an email no account uses says so, and links to sign-up',
      (tester) async {
    await pumpApp(tester);
    await tapLogIn(tester); // on Welcome

    await enterField(tester, AppStrings.email, 'nobody@example.com');
    await enterField(tester, AppStrings.password, 'some-password');
    await tapLogIn(tester);
    expect(find.text(AppStrings.noAccountFound), findsOneWidget);

    await tapAndSettle(tester, AppStrings.newHereCreateAccount);
    expect(find.text(AppStrings.newToKuzuHelp), findsOneWidget); // back on Welcome
  });

  testWidgets('a new customer signs up with a code, sets a password and lands on Customer Home',
      (tester) async {
    final auth = (await pumpApp(tester)).auth;

    await tapAndSettle(tester, AppStrings.needService);
    expect(find.text(AppStrings.signUpTitle), findsOneWidget);
    expect(find.widgetWithText(TextFormField, AppStrings.password), findsNothing);

    await enterField(tester, AppStrings.name, 'Pema Dorji');
    await enterField(tester, AppStrings.email, ' Pema@Example.com ');
    await tapAndSettle(tester, AppStrings.sendCode);
    expect(auth.sentCodes.single,
        (email: 'pema@example.com', fullName: 'Pema Dorji', role: UserRole.customer));
    expect(find.text(AppStrings.codeSentTo('pema@example.com')), findsOneWidget);

    await enterCode(tester, '123456');
    expect(find.text(AppStrings.createPasswordTitle), findsOneWidget);

    await setPassword(tester, 'druk-2026');
    expect(auth.savedPassword, 'druk-2026');
    expect(customerHome, findsOneWidget);
  });

  testWidgets('a new worker signs up, sets a password and lands on worker profile setup',
      (tester) async {
    final auth = (await pumpApp(tester, role: UserRole.worker)).auth;

    await tapAndSettle(tester, AppStrings.offerService);
    await enterField(tester, AppStrings.name, 'Karma Wangdi');
    await enterField(tester, AppStrings.email, 'karma@example.com');
    await tapAndSettle(tester, AppStrings.sendCode);
    expect(auth.sentCodes.single.role, UserRole.worker);

    await enterCode(tester, '123456');
    await setPassword(tester, 'druk-2026');
    expect(workerSetup, findsOneWidget);
  });

  testWidgets('a wrong code shows an error', (tester) async {
    final auth = (await pumpApp(tester)).auth;

    await signUpUntilCode(tester);
    await enterCode(tester, '000000');
    expect(find.text(AppStrings.wrongCode), findsOneWidget);
    expect(auth.isLoggedIn, isFalse);
  });

  testWidgets('the password must be long enough and typed the same twice', (tester) async {
    final auth = (await pumpApp(tester)).auth;
    await signUpUntilCode(tester);
    await enterCode(tester, '123456');

    await setPassword(tester, 'short');
    expect(find.text(AppStrings.passwordTooShort(AppConstants.minPasswordLength)), findsOneWidget);

    await enterField(tester, AppStrings.password, 'druk-2026');
    await enterField(tester, AppStrings.confirmPassword, 'druk-2027');
    await tapAndSettle(tester, AppStrings.savePassword);
    expect(find.text(AppStrings.passwordsDontMatch), findsOneWidget);
    expect(auth.savedPassword, isNull);
  });

  testWidgets('log in asks for email and password, not a code; a wrong password shows an error',
      (tester) async {
    final auth = (await pumpApp(tester, hasPassword: true)).auth;

    await tapLogIn(tester); // on Welcome
    expect(find.text(AppStrings.logInHint), findsOneWidget);
    expect(find.widgetWithText(TextFormField, AppStrings.name), findsNothing);
    expect(find.text(AppStrings.sendCode), findsNothing);

    await enterField(tester, AppStrings.email, ' Dorji@Example.com ');
    await enterField(tester, AppStrings.password, 'wrong-password');
    await tapLogIn(tester);
    expect(find.text(AppStrings.wrongPassword), findsOneWidget);
    expect(auth.isLoggedIn, isFalse);

    await enterField(tester, AppStrings.password, FakeAuthRepository.correctPassword);
    await tapLogIn(tester);
    expect(auth.passwordLogIns, ['dorji@example.com', 'dorji@example.com']);
    expect(auth.sentCodes, isEmpty);
    expect(customerHome, findsOneWidget);
  });

  testWidgets('Forgot password? emails a code, then asks for a new password', (tester) async {
    final auth = (await pumpApp(tester, hasPassword: true)).auth;
    await tapLogIn(tester); // on Welcome

    // Only the email is needed, and it's checked first.
    await tapAndSettle(tester, AppStrings.forgotPassword);
    expect(find.text(AppStrings.invalidEmail), findsOneWidget);
    expect(find.text(AppStrings.enterPassword), findsNothing);
    expect(auth.sentCodes, isEmpty);

    await enterField(tester, AppStrings.email, 'dorji@example.com');
    await tapAndSettle(tester, AppStrings.forgotPassword);
    expect(auth.sentCodes.single, (email: 'dorji@example.com', fullName: null, role: null));

    await enterCode(tester, '123456');
    expect(find.text(AppStrings.newPasswordTitle), findsOneWidget);

    await setPassword(tester, 'new-druk-2026');
    expect(auth.savedPassword, 'new-druk-2026');
    expect(customerHome, findsOneWidget);
  });

  for (final (role, home) in [(UserRole.customer, customerHome), (UserRole.worker, workerSetup)]) {
    testWidgets('a $role who closed the app before setting a password must set it on the next start',
        (tester) async {
      await pumpApp(tester, role: role, loggedIn: true);
      expect(find.text(AppStrings.createPasswordTitle), findsOneWidget);
      expect(find.byType(BackButton), findsNothing);

      await setPassword(tester, 'druk-2026');
      expect(home, findsOneWidget);
    });
  }

  testWidgets('admins are not made to set a password', (tester) async {
    await pumpApp(tester, role: UserRole.admin, loggedIn: true);
    expect(find.text(AppStrings.createPasswordTitle), findsNothing);
    expect(customerHome, findsOneWidget); // admins use the app as customers
  });

  testWidgets('admins can log in with an email code alone', (tester) async {
    final auth = (await pumpApp(tester, role: UserRole.admin)).auth;

    await tapLogIn(tester); // on Welcome
    await enterField(tester, AppStrings.email, 'admin@example.com');
    await tapAndSettle(tester, AppStrings.forgotPassword);
    await enterCode(tester, '123456');

    expect(find.text(AppStrings.newPasswordTitle), findsNothing);
    expect(customerHome, findsOneWidget);
    expect(auth.savedPassword, isNull);
  });

  testWidgets('a missing name and a bad email are caught before sending', (tester) async {
    final auth = (await pumpApp(tester)).auth;

    await tapAndSettle(tester, AppStrings.needService);
    await enterField(tester, AppStrings.email, 'not-an-email');
    await tapAndSettle(tester, AppStrings.sendCode);

    expect(find.text(AppStrings.enterName), findsOneWidget);
    expect(find.text(AppStrings.invalidEmail), findsOneWidget);
    expect(auth.sentCodes, isEmpty);
  });

  testWidgets('Resend code unlocks after 60 seconds', (tester) async {
    final auth = (await pumpApp(tester)).auth;

    await signUpUntilCode(tester);
    expect(find.text(AppStrings.resendIn(60)), findsOneWidget);

    await tester.pump(const Duration(seconds: 60));
    await tapAndSettle(tester, AppStrings.resendCode);
    expect(auth.sentCodes, hasLength(2));
    expect(find.text(AppStrings.codeResent), findsOneWidget);
    expect(find.text(AppStrings.resendIn(60)), findsOneWidget);
  });

  testWidgets('logged-in users skip Welcome after a restart', (tester) async {
    await pumpApp(tester, loggedIn: true, hasPassword: true);
    expect(customerHome, findsOneWidget);
  });
}
