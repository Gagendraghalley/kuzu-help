import '../constants/app_constants.dart';

class PhoneUtils {
  /// Always store numbers as +975XXXXXXXX.
  static String toInternational(String input) {
    final digits = input.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.startsWith('975')) return '+$digits';
    return '${AppConstants.countryCode}$digits';
  }

  /// Bhutan mobile numbers are 8 digits starting with 17 or 77.
  static bool isValidMobile(String input) {
    final n = toInternational(input);
    return RegExp(r'^\+975(17|77)\d{6}$').hasMatch(n);
  }
}
