import 'package:flutter/foundation.dart';
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
    }
    // A database function the app calls isn't there (see supabase/updates.sql).
    if (error is PostgrestException && error.code == 'PGRST202') {
      return AppStrings.databaseUpdateNeeded;
    }
    // Everything else, including no internet and database errors.
    return AppStrings.genericError;
  }
}
