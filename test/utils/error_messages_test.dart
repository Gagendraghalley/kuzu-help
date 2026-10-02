import 'package:bhutan_services/core/strings/app_strings.dart';
import 'package:bhutan_services/core/utils/error_messages.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  test('wrong or expired code', () {
    const e = AuthException('Token has expired or is invalid', statusCode: '403', code: 'otp_expired');
    expect(ErrorMessages.from(e), AppStrings.wrongCode);
  });

  test('logging in with an email that has no account', () {
    const e = AuthException('Signups not allowed for otp', statusCode: '422', code: 'otp_disabled');
    expect(ErrorMessages.from(e), AppStrings.noAccountFound);
  });

  test('wrong email or password', () {
    const e = AuthException('Invalid login credentials', statusCode: '400', code: 'invalid_credentials');
    expect(ErrorMessages.from(e), AppStrings.wrongPassword);
  });

  test('a password the server thinks is too weak', () {
    const e = AuthException('Password is known to be weak', statusCode: '422', code: 'weak_password');
    expect(ErrorMessages.from(e), AppStrings.weakPassword);
  });

  test('asking for codes too often', () {
    const byCode = AuthException('email rate limit exceeded', code: 'over_email_send_rate_limit');
    const byStatus = AuthException('Too many requests', statusCode: '429');
    expect(ErrorMessages.from(byCode), AppStrings.tooManyAttempts);
    expect(ErrorMessages.from(byStatus), AppStrings.tooManyAttempts);
  });

  test('a database function or table from updates.sql is missing', () {
    const function = PostgrestException(message: 'Could not find the function', code: 'PGRST202');
    const table = PostgrestException(message: "Could not find the table 'public.notifications'", code: 'PGRST205');
    expect(ErrorMessages.from(function), AppStrings.databaseUpdateNeeded);
    expect(ErrorMessages.from(table), AppStrings.databaseUpdateNeeded);
  });

  test("a ground's subscription has ended, or an admin pays a second month ahead", () {
    const ended = PostgrestException(message: "This ground's subscription has ended", code: 'KH402');
    const ahead = PostgrestException(message: 'Already paid until ...', code: 'KH409');
    expect(ErrorMessages.from(ended), AppStrings.subscriptionEndedError);
    expect(ErrorMessages.from(ahead), AppStrings.oneMonthAtATime);
    const paid = PostgrestException(message: 'Paid until ...: months paid for stay', code: 'KH410');
    expect(ErrorMessages.from(paid), AppStrings.paidMonthsStay);
    const notSetUp = PostgrestException(message: "Invoice emails aren't set up yet: pg_net is off.", code: 'KH503');
    expect(ErrorMessages.from(notSetUp), "Invoice emails aren't set up yet: pg_net is off.");
  });

  test('the delete-account Edge Function is not deployed', () {
    expect(ErrorMessages.from(const FunctionException(status: 404)), AppStrings.accountDeletionNotSetUp);
    expect(ErrorMessages.from(const FunctionException(status: 500)), AppStrings.genericError);
  });

  test("Apple's sheet failing, or Google or Apple not turned on in Supabase", () {
    const apple = SignInWithAppleAuthorizationException(code: AuthorizationErrorCode.failed, message: '');
    const off = AuthException('Provider is not enabled', statusCode: '400', code: 'provider_disabled');
    expect(ErrorMessages.from(apple), AppStrings.appleSignInFailed);
    expect(ErrorMessages.from(off), AppStrings.signInMethodOff);
  });

  test('anything else gets the general message', () {
    expect(ErrorMessages.from(Exception('Failed host lookup')), AppStrings.genericError);
    expect(ErrorMessages.from(const AuthException('Something odd')), AppStrings.genericError);
  });
}
