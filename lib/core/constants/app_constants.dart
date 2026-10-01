class UserRole {
  static const customer = 'customer'; // uses the home services
  static const worker = 'worker';
  static const admin = 'admin';
  static const groundManager = 'ground_manager'; // runs a sports venue and its grounds; an admin makes them one
  static const player = 'player'; // books sports grounds; signs up from a ground

  /// The roles an account adds for itself, one for each service: signing up
  /// for another service with the same email adds it (add_my_role).
  static const addable = {customer, player};
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
  static const venuePhotos = 'venue-photos';           // public: venues' cover photos
}

/// venues.venue_type values (supabase/updates.sql, section 13).
class VenueType {
  static const sportsGround = 'sports_ground';
  static const restaurant = 'restaurant'; // party bookings, later
  static const bar = 'bar';               // party bookings, later
}

/// grounds.sport values.
class Sport {
  static const futsal = 'futsal';
  static const football = 'football';
  static const basketball = 'basketball';
  static const badminton = 'badminton';
  static const other = 'other';
  static const all = [futsal, football, basketball, badminton, other];
}

/// ground_bookings.status values. Only set_booking_status changes them.
class BookingStatus {
  static const pending = 'pending';
  static const confirmed = 'confirmed';
  static const rejected = 'rejected';
  static const cancelled = 'cancelled';
  static const completed = 'completed';
  static const noShow = 'no_show';

  /// Still holding its time on the ground.
  static bool isOpen(String status) => status == pending || status == confirmed;
}

/// ground_bookings.kind values: a customer's booking, or time the owner blocked.
class BookingKind {
  static const customer = 'customer';
  static const ownerBlock = 'owner_block';
  static const phone = 'phone'; // the manager booked it for someone who called
}

/// ground_bookings.payment_method values.
class PaymentMethod {
  static const payAtVenue = 'pay_at_venue';
  static const mbob = 'mbob_transfer';
  static const mpay = 'mpay_transfer';
  static const all = [payAtVenue, mbob, mpay];
}

/// ground_bookings.payment_status values.
class PaymentStatus {
  static const unpaid = 'unpaid';
  static const depositClaimed = 'deposit_claimed'; // the customer gave a journal number
  static const paid = 'paid';                      // the owner marked it paid
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
  // Sports grounds (supabase/updates.sql, section 13)
  static const venueAssigned = 'venue_assigned';             // the new manager
  static const bookingNew = 'booking_new';                   // the manager
  static const bookingConfirmed = 'booking_confirmed';       // the customer
  static const bookingRejected = 'booking_rejected';         // the customer
  static const bookingCancelled = 'booking_cancelled';       // whoever didn't cancel ('by')
  static const bookingExpired = 'booking_expired';           // the customer
  static const bookingCompleted = 'booking_completed';       // the customer
  static const venueReviewNew = 'venue_review_new';          // the manager
  static const venueReviewUpdated = 'venue_review_updated';  // the manager
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
  // Match ground_slot_price in supabase/updates.sql, section 13: from now to a week ahead.
  static const bookingDaysAhead = 7;
  // How far ahead a manager can block time (repairs, a tournament).
  static const blockDaysAhead = 60;
}
