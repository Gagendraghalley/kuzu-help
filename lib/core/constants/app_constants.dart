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
  static const workPhotos = 'work-photos';             // public
  static const jobPhotos = 'job-photos';               // private: the customer, the job's worker, admins
}

/// job_requests.status values (supabase/updates.sql, section 11).
class JobStatus {
  static const pending = 'pending';
  static const accepted = 'accepted';
  static const declined = 'declined';
  static const cancelled = 'cancelled';
  static const completed = 'completed';

  /// Still going on: shown under 'Active'; only one per customer and worker.
  static bool isOpen(String status) => status == pending || status == accepted;
}

/// reports.status values. Only admins change them (set_report_status in updates.sql).
class ReportStatus {
  static const open = 'open';
  static const reviewed = 'reviewed';
  static const closed = 'closed';
  static const all = [open, reviewed, closed];
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

/// notifications.type values (supabase/updates.sql, section 5).
class NotificationTypes {
  static const welcome = 'welcome';
  static const newUser = 'new_user';                     // admins
  static const workerSubmitted = 'worker_submitted';     // admins
  static const workerResubmitted = 'worker_resubmitted'; // admins
  static const reportNew = 'report_new';                 // admins
  static const workerApproved = 'worker_approved';
  static const workerRejected = 'worker_rejected';
  static const reviewNew = 'review_new';
  static const reviewUpdated = 'review_updated';
  static const contact = 'contact';
  static const reportUpdated = 'report_updated';
  static const accountDeactivated = 'account_deactivated';
  static const accountReactivated = 'account_reactivated';
  static const reviewReply = 'review_reply';
  static const jobNew = 'job_new';             // the worker
  static const jobAccepted = 'job_accepted';   // the customer
  static const jobDeclined = 'job_declined';   // the customer
  static const jobCancelled = 'job_cancelled'; // the worker
  static const jobCompleted = 'job_completed'; // whoever didn't mark it done
}

/// C3: which contact button a customer tapped (record_contact in updates.sql).
class ContactMethod {
  static const call = 'call';
  static const whatsapp = 'whatsapp';
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
  static const maxWorkPhotos = 12; // match work_photos in supabase/updates.sql
}
