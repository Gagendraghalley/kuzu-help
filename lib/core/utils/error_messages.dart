import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show PlatformException;
import 'package:google_sign_in/google_sign_in.dart' show GoogleSignInException;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../strings/app_strings.dart';

/// Turn technical errors into friendly text for the user.
class ErrorMessages {
  static String from(Object error) {
    if (kDebugMode) debugPrint('ErrorMessages.from: $error'); // the real cause, for you

    if (error is AuthException) {
      final code = error.code;
      if (code == ErrorCode.otpExpired.code) return AppStrings.wrongCode;
      // Wrong password, or no account uses the email (Supabase doesn't say which).
      // Not in this version's ErrorCode list.
      if (code == 'invalid_credentials') return AppStrings.wrongPassword;
      if (code == ErrorCode.weakPassword.code) return AppStrings.weakPassword;
      // 'Secure password change' is on and the login is over a day old.
      if (code == ErrorCode.reauthenticationNeeded.code) return AppStrings.reauthenticationNeeded;
      // Logging in (not signing up) with an email that has no account.
      if (code == ErrorCode.otpDisabled.code) return AppStrings.noAccountFound;
      if (code == ErrorCode.overEmailSendRateLimit.code ||
          code == ErrorCode.overRequestRateLimit.code ||
          error.statusCode == '429') {
        return AppStrings.tooManyAttempts;
      }
      if (code == ErrorCode.validationFailed.code) return AppStrings.invalidEmail;
      // Google isn't turned on in Supabase (README).
      if (code == ErrorCode.providerDisabled.code) return AppStrings.googleSignInFailed;
    }
    // Google's account picker failed (not closed: that's no error), or
    // couldn't open: on iPhones, a missing URL scheme in Info.plist (README).
    if (error is GoogleSignInException || (error is PlatformException && error.code == 'google_sign_in')) {
      return AppStrings.googleSignInFailed;
    }
    // A database function, table or column the app uses isn't there (see supabase/updates.sql).
    if (error is PostgrestException &&
        (error.code == 'PGRST202' || error.code == 'PGRST204' || error.code == 'PGRST205')) {
      return AppStrings.databaseUpdateNeeded;
    }
    // The delete-account Edge Function isn't deployed (see the README).
    if (error is FunctionException && error.status == 404) {
      return AppStrings.accountDeletionNotSetUp;
    }
    // Everything else, including no internet and database errors.
    return AppStrings.genericError;
  }
}
