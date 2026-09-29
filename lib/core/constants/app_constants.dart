class UserRole {
  static const customer = 'customer';
  static const worker = 'worker';
  static const admin = 'admin';
}

class VerificationStatus {
  static const pending = 'pending';
  static const approved = 'approved';
  static const rejected = 'rejected';
}

class Buckets {
  static const avatars = 'avatars';                    // public
  static const verificationDocs = 'verification-docs'; // private
}

class ReportReasons {
  static const all = [
    'did_not_show_up',
    'poor_work',
    'overcharged',
    'rude_or_unsafe',
    'other',
  ];
}

/// C2 sort orders.
enum WorkerSort { rating, reviews, experience }

class AppConstants {
  static const countryCode = '+975';
  static const defaultDzongkhag = 'Thimphu'; // C1, until the customer picks one
  static const otpLength = 6;
  static const otpResendSeconds = 60;
  static const minPasswordLength = 8; // match Supabase > Auth > Email > Minimum password length
  static const maxImageKb = 200;
}
