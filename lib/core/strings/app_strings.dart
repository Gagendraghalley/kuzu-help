import '../constants/app_constants.dart';

/// ALL display text lives here so Dzongkha can be added later
/// without rewriting screens.
class AppStrings {
  static const appName = 'Kuzu Help';

  // Welcome (A2)
  static const tagline = 'Find trusted local workers near you';
  static const needService = 'I need a service';
  static const needServiceHint = 'Find a plumber, electrician, carpenter and more';
  static const offerService = 'I offer a service';
  static const offerServiceHint = 'Get more customers for your skills';
  static const newToKuzuHelp = 'New to Kuzu Help? Create a free account:';
  static const alreadyHaveAccount = 'Already have an account?';

  // Login (A3, A4, A5)
  static const signUpTitle = 'Create your account';
  static const logInTitle = 'Log in';
  static const codeByEmail =
      "We'll email you a 6-digit code to confirm your email. Then you'll choose a password.";
  static const logInHint = 'Use your email and the password you created.';
  static const name = 'Full name';
  static const email = 'Email';
  static const phone = 'Phone number';
  static const password = 'Password';
  static const confirmPassword = 'Confirm password';
  static const showPassword = 'Show password';
  static const hidePassword = 'Hide password';
  static const enterName = 'Please enter your name';
  static const invalidEmail = 'Please enter a valid email address';
  static const enterPassword = 'Please enter your password';
  static const sendCode = 'Send code';
  static const logIn = 'Log in';
  static const forgotPassword = 'Forgot password?';
  static const sendingCode = 'Sending code…';
  static const wrongPassword =
      "Wrong email or password. If you haven't set a password yet, tap 'Forgot password?'.";
  static String signingUpAs(String role) => role == UserRole.worker
      ? 'You are signing up to offer your services.'
      : 'You are signing up to find workers.';
  static const newHereCreateAccount = 'New to Kuzu Help? Create an account';
  static const alreadyRegisteredTitle = 'This email is already registered';
  static const alreadyRegisteredHelp = 'Log in with this email and your password instead. '
      "Forgot your password? Tap 'Forgot password?' on the log in screen.";
  static const alreadyRegisteredWorkerTip =
      "To offer your services with this account, log in, open Settings and tap 'Become a worker'.";
  static const logInInstead = 'Log in instead';
  static const createPasswordTitle = 'Create a password';
  static const newPasswordTitle = 'Choose a new password';
  static const createPasswordHint = "You'll use it with your email to log in next time.";
  static String passwordHint(int min) => 'At least $min characters';
  static String passwordTooShort(int min) => 'Please use at least $min characters';
  static const passwordsDontMatch = "The passwords don't match";
  static const weakPassword = 'Please choose a stronger password, with letters and numbers.';
  static const savePassword = 'Save password';
  static const changePassword = 'Change password';
  static const changePasswordHint = 'Use it with your email the next time you log in.';
  static const passwordChanged = 'Your password is changed';
  static const reauthenticationNeeded =
      "For your safety, please log out and use 'Forgot password?' to change your password.";
  static const noAccountFound =
      'No account uses this email yet. Go back and choose '
      '"I need a service" or "I offer a service" to sign up.';
  static const verifyTitle = 'Check your email';
  static String codeSentTo(String email) => 'Enter the 6-digit code we sent to $email';
  static const enterCode = 'Enter the 6-digit code';
  static const verify = 'Verify';
  static const resendCode = 'Resend code';
  static String resendIn(int seconds) => 'Resend code in ${seconds}s';
  static const codeResent = 'A new code is on its way.';
  static const wrongCode = 'That code is wrong or has expired. Please try again.';
  static const tooManyAttempts = 'Too many attempts. Please wait a minute and try again.';

  // Worker (B)
  static const pendingMessage =
      'Your profile is being checked. This usually takes 1–2 days.';
  static const availableForWork = 'Available for work';
  static const notAvailable = 'Not available';
  static const cidExplanation =
      'We need a photo of your CID to confirm who you are. '
      'It stays private and is only seen by our team.';
  static String setupStep(int step, int of) => 'Step $step of $of';

  // B1 Profile setup
  static const workerProfileTitle = 'Your worker profile';
  static const workerProfileHint = 'This is what customers see. Clear details get more calls.';
  static const photoHint = 'A clear photo of your face helps customers trust you.';
  static const addPhoto = 'Add photo';
  static const changePhoto = 'Change photo';
  static const takePhoto = 'Take a photo';
  static const chooseFromGallery = 'Choose from gallery';
  static const photoAccessDenied =
      'Could not open the camera or photos. Please allow access in your phone settings.';
  static const mobileNumber = 'Mobile number (calls and WhatsApp)';
  static const mobileHint = '17XXXXXX or 77XXXXXX';
  static const invalidMobile = 'Please enter an 8-digit number starting with 17 or 77';
  static const dzongkhag = 'Dzongkhag';
  static const chooseDzongkhag = 'Please choose your dzongkhag';
  static const town = 'Town or village (optional)';
  static const yearsExperience = 'Years of experience';
  static const invalidYears = 'Please enter a number from 0 to 60';
  static const bio = 'About you (optional)';
  static const bioHint = 'e.g. I have fixed taps, pipes and water tanks in Thimphu for 8 years.';
  static const saveAndContinue = 'Save and continue';
  static const save = 'Save';
  static const saved = 'Saved';

  // B2 Services and prices
  static const servicesTitle = 'Your services';
  static const servicesHint =
      'Tick the work you do. A price is optional, but customers find it helpful.';
  static const priceNote = 'Price (optional)';
  static const priceNoteHint = 'e.g. Nu 500 per visit';
  static const chooseOneService = 'Please choose at least one service';

  // B3 Verification
  static const verificationTitle = 'Confirm who you are';
  static const cidPhoto = 'CID card photo';
  static const certificatePhoto = 'Training certificate (optional)';
  static const certificateHint = 'If you have one, it shows our team you are trained.';
  static const tapToAddPhoto = 'Tap to take or choose a photo';
  static const photoReady = 'Photo ready to send. Tap to change.';
  static const alreadySent = 'Already sent. Tap to replace.';
  static const addCidPhoto = 'Please add a photo of your CID card';
  static const consent =
      'I agree that the Kuzu Help team may look at these documents to confirm who I am.';
  static const consentNeeded = 'Please tick the box to agree';
  static const sendForChecking = 'Send for checking';

  // B4 Pending approval
  static const pendingTitle = 'Thanks! We have your details';
  static const rejectedTitle = 'Your profile needs changes';
  static const rejectedMessage = 'Please fix the details below, then send them for checking again.';
  static const approvedTitle = "You're approved!";
  static const approvedMessage = 'Customers can now find you and call you.';
  static const adminNoteLabel = 'Message from our team';
  static const stepProfile = 'Profile';
  static const stepServices = 'Services';
  static const stepDocuments = 'Documents';
  static const stepTeamCheck = 'Checked by our team';
  static const stepDone = 'Done';
  static const stepWaiting = 'Waiting';
  static const needChanges = 'Need to change something?';
  static const editProfile = 'Edit profile';
  static const editServices = 'Edit services';
  static const updateDocuments = 'Update documents';
  static const sendAgain = 'Send for checking again';
  static const checkAgain = 'Check again';
  static const goToDashboard = 'Go to my dashboard';

  // B5 Worker dashboard
  static const availableHint = 'Customers can see you are taking work.';
  static const notAvailableHint = 'Customers see that you are busy right now.';
  static const yourServices = 'Your services';
  static const edit = 'Edit';
  static const seePublicProfile = 'View my public profile';
  static const recentReviews = 'Recent reviews';
  static const noReviewsForWorker = 'No reviews yet. Reviews from your customers will show here.';
  static const notListedNow = "Customers can't see your profile right now.";
  static const seeMyStatus = 'See my status';

  // Customer (C)
  static const call = 'Call';
  static const whatsapp = 'WhatsApp';
  static const writeReview = 'Write a review';
  static const reportWorker = 'Report this worker';
  static const verified = 'Verified';
  static const available = 'Available';
  static String noWorkersYet(String service) =>
      'No ${service.toLowerCase()}s in this area yet – check back soon';
  static String noWorkersAnywhere(String service) =>
      'No ${service.toLowerCase()}s yet – check back soon';
  static const allDzongkhags = 'All dzongkhags';
  static const awaitingApproval = 'Awaiting approval';
  static const notApproved = 'Not approved';

  // Admin (Phase 5): approving workers
  static const adminCheck = 'Admin check';
  static const adminPendingHint =
      "Customers can't see this worker until you approve them. Check their details and CID first.";
  static const adminApprovedHint = 'Approved: customers can find and call this worker.';
  static const adminRejectedHint =
      'Rejected: the worker sees your note and can send their details again.';
  static const cid = 'CID';
  static const certificate = 'Certificate';
  static const noDocumentsYet = "They haven't sent their documents yet.";
  static const approve = 'Approve';
  static const reject = 'Reject';
  static String workerApproved(String name) => '$name is approved. Customers can now see them.';
  static String workerRejected(String name) => '$name is rejected. They will see your note.';
  static const rejectTitle = 'What should they fix?';
  static const rejectHint = 'e.g. Your CID photo is blurry. Please take it again in good light.';
  static const rejectNoteNeeded = 'Please tell the worker what to fix';
  static const workersAwaitingApproval = 'Workers awaiting approval';
  static const noneAwaitingApproval = 'No workers are waiting for approval.';
  static const close = 'Close';
  static const databaseUpdateNeeded =
      'The database needs an update: run supabase/updates.sql in the Supabase SQL Editor.';

  // Admin: deactivating (blacklisting) users
  static const users = 'Users';
  static const searchUsers = 'Search by name or email';
  static const noUsersFound = 'No users found.';
  static const deactivated = 'Deactivated';
  static const deactivateAccount = 'Deactivate account';
  static const reactivateAccount = 'Reactivate account';
  static const deactivateTitle = 'Deactivate this account?';
  static const deactivateHint = 'Reason (they will see it), e.g. Several reports of not showing up.';
  static const deactivate = 'Deactivate';
  static const deactivatedWorkerHint =
      "Deactivated: customers can't see this worker, and they can't use the app.";
  static String userDeactivated(String name) => '$name is deactivated.';
  static String userReactivated(String name) => '$name can use the app again.';
  static const adminsCantBeDeactivated = "Admins can't be deactivated.";
  static const openWorkerPage = 'Open worker page';

  // Admin: reports from customers (C5)
  static const reports = 'Reports';
  static String reportStatusLabel(String status) => switch (status) {
        ReportStatus.reviewed => 'Reviewed',
        ReportStatus.closed => 'Closed',
        _ => 'Open',
      };
  static String noReports(String status) => 'No ${reportStatusLabel(status).toLowerCase()} reports.';
  static String reportedBy(String name) => 'Reported by ${name.isEmpty ? 'a customer' : name}';
  static const reportHandlingHint = "Check the worker's page, and deactivate them there if needed. "
      'The customer who sent the report is told when you mark it reviewed or closed.';
  static const markReviewed = 'Mark as reviewed';
  static const closeReport = 'Close report';
  static const reopenReport = 'Open again';
  static String reportStatusChanged(String status) => switch (status) {
        ReportStatus.reviewed => 'Marked as reviewed. The customer who sent it is told.',
        ReportStatus.closed => 'Report closed. The customer who sent it is told.',
        _ => 'The report is open again.',
      };

  // Shown to a deactivated user
  static const deactivatedTitle = 'Your account is deactivated';
  static const deactivatedMessage = "You can't use Kuzu Help with this account. "
      'If you think this is a mistake, please contact the Kuzu Help team.';
  static const whatsappGreeting =
      'Kuzuzangpo! I found you on Kuzu Help and would like to ask about your work.';

  // C1 Customer home
  static String greeting(String? name) =>
      name == null || name.isEmpty ? 'Kuzuzangpo!' : 'Kuzuzangpo, $name';
  static const whatDoYouNeed = 'What do you need help with?';
  static const yourArea = 'Your area';
  static const chooseArea = 'Choose your dzongkhag';
  static const trustNote = 'Every worker is checked by our team before they appear here.';
  static const noServicesYet = 'No services are listed yet – check back soon.';

  // C2 Worker list
  static const sortBy = 'Sort by';
  static String sortLabel(WorkerSort sort) => switch (sort) {
        WorkerSort.rating => 'Highest rated',
        WorkerSort.reviews => 'Most reviews',
        WorkerSort.experience => 'Most experienced',
      };
  static String reviewCount(int n) => n == 1 ? '1 review' : '$n reviews';
  static String years(int n) => n == 1 ? '1 year' : '$n years';
  static const noReviewsShort = 'No reviews yet';

  // C3 Worker details
  static const rating = 'Rating';
  static const reviews = 'Reviews';
  static const yearsLabel = 'Years of work';
  static const newWorker = 'New';
  static const about = 'About';
  static const services = 'Services';
  static const askForPrice = 'Ask for the price';
  static const editReview = 'Edit your review';
  static const noReviewsYet = 'No reviews yet. Be the first to share how the work went.';
  static const workerNotListed = 'This worker is not listed any more.';
  static const notAvailableNow = 'Not taking new work right now. You can still call to ask.';
  static const yourPublicProfile = 'This is how customers see your profile.';
  static const cannotOpenPhone = 'Could not open the phone app on this device.';
  static const cannotOpenWhatsapp = 'Could not open WhatsApp. Is it installed?';

  // C4 Write a review
  static const howWasTheWork = 'How was the work?';
  static String ratingWord(int stars) =>
      const ['', 'Poor', 'Fair', 'Good', 'Very good', 'Excellent'][stars];
  static String starsLabel(int n) => n == 1 ? '1 star' : '$n stars';
  static String ratedOutOf5(double rating) => 'Rated ${rating.toStringAsFixed(1)} out of 5';
  static const chooseRating = 'Please tap the stars to give a rating';
  static const reviewComment = 'Tell others about the work (optional)';
  static const reviewCommentHint = 'Was it on time? Was the price fair? Would you call again?';
  static const postReview = 'Post review';
  static const updateReview = 'Update review';
  static const reviewSaved = 'Thank you for your review!';

  // C5 Report a worker
  static const reportIntro =
      'Tell us what went wrong. Our team reads every report, '
      'and the worker is not told who reported them.';
  static const whatHappened = 'What happened?';
  static String reportReason(String code) => switch (code) {
        'did_not_show_up' => 'Did not show up',
        'poor_work' => 'Poor quality work',
        'overcharged' => 'Charged too much',
        'rude_or_unsafe' => 'Rude or unsafe behaviour',
        _ => 'Something else',
      };
  static const chooseReason = 'Please choose what happened';
  static const reportDetails = 'Details';
  static const reportDetailsOptional = 'Details (optional)';
  static const reportDetailsHint = 'What happened, and when?';
  static const reportDetailsNeeded = 'Please tell us what happened';
  static const sendReport = 'Send report';
  static const reportSent = 'Thank you. Our team will look into it.';

  // Reviews only after getting in touch; workers' replies
  static const reviewAfterContact =
      'You can review this worker after you call, message or send them a job request.';
  static const reply = 'Reply';
  static const editReply = 'Edit reply';
  static const replyTitle = 'Reply to this review';
  static const replyHint = 'e.g. Thank you! Sorry I was late, the road was closed.';
  static const replyNeeded = 'Please write your reply';
  static const replyFromWorker = 'Reply from the worker';
  static const replySaved = 'Your reply is saved. The customer is told.';

  // Photos of past work
  static const workPhotos = 'Photos of work';
  static const yourWorkPhotos = 'Photos of your work';
  static String workPhotosHint(int max) =>
      'Show customers jobs you have finished. They see these on your page. Up to $max photos.';
  static const noWorkPhotos = 'No photos yet. Add photos of jobs you have finished.';
  static String workPhotosFull(int max) => 'You have $max photos. Remove one to add another.';
  static const removePhotoTitle = 'Remove this photo?';
  static const remove = 'Remove';
  static const photoAdded = 'Photo added. Customers can see it now.';

  // Search and saved workers
  static const searchWorkers = 'Search workers by name';
  static const typeToSearch = 'Type at least 2 letters of a name.';
  static String noWorkersNamed(String name) => 'No workers called "$name" yet.';
  static const availableNow = 'Available now';
  static String noneAvailableNow(String service) =>
      'No ${service.toLowerCase()}s are available right now. Turn off "$availableNow" to see everyone.';
  static const savedWorkers = 'Saved workers';
  static const saveWorker = 'Save worker';
  static const unsaveWorker = 'Remove from saved workers';
  static const workerSaved = 'Saved. Find them under Saved workers.';
  static const workerUnsaved = 'Removed from saved workers.';
  static const noSavedWorkers = "No saved workers yet. Tap the heart on a worker's page to save them.";

  // Job requests
  static const requestJob = 'Request a job';
  static const myJobRequests = 'My job requests';
  static const jobRequests = 'Job requests';
  static String jobRequestIntro(String name) =>
      "Tell $name what you need. They'll answer here, and can call you on your number.";
  static const jobService = 'Service';
  static const jobDescription = 'What needs doing?';
  static const jobDescriptionHint = 'e.g. The kitchen tap drips and the pipe under the sink leaks.';
  static const describeJob = 'Please describe the job';
  static const jobWhen = 'When do you need it? (optional)';
  static const jobWhenHint = 'e.g. Tomorrow morning, or any weekday';
  static const jobAddress = 'Where is the job?';
  static const jobAddressHint = 'e.g. Changzamtog, near the school';
  static const enterAddress = 'Please say where the job is';
  static const jobPhone = 'Your phone number';
  static const jobPhoto = 'Photo of the job (optional)';
  static const jobPhotoHint = "A photo helps the worker see what's needed.";
  static const sendRequest = 'Send request';
  static const jobRequestSent = "Request sent. We'll let you know when they answer.";
  static const jobAlreadyOpen = 'You already have an open request with this worker.';
  static const seeYourRequest = 'See your job request';
  static const workerNotTakingWork = "This worker isn't taking new work right now.";
  static String jobStatusLabel(String status) => switch (status) {
        JobStatus.accepted => 'Accepted',
        JobStatus.declined => 'Declined',
        JobStatus.cancelled => 'Cancelled',
        JobStatus.completed => 'Done',
        _ => 'Waiting for answer',
      };
  static const activeJobs = 'Active';
  static const pastJobs = 'Past';
  static String noJobs({required bool active, required bool asWorker}) => active
      ? asWorker
          ? 'No job requests right now. New ones show here and under the bell.'
          : 'No open requests. Find a worker and tap "$requestJob".'
      : 'Nothing here yet.';
  static String newJobRequests(int n) =>
      n == 0 ? 'No new requests' : n == 1 ? '1 new request' : '$n new requests';
  static String jobFrom(String name) => 'From ${name.isEmpty ? 'a customer' : name}';
  static String jobTo(String name) => 'To ${name.isEmpty ? 'a worker' : name}';
  static const jobWhenLabel = 'When';
  static const jobWhereLabel = 'Where';
  static const jobPhoneLabel = 'Phone';
  static const messageFromWorker = 'Message from the worker';
  static const acceptJob = 'Accept';
  static const declineJob = 'Decline';
  static const markDone = 'Mark as done';
  static const cancelRequest = 'Cancel request';
  static const acceptJobTitle = 'Accept this job?';
  static const acceptJobHint = 'Message for the customer (optional), e.g. I can come at 9am.';
  static const declineJobTitle = 'Decline this job?';
  static const declineJobHint = 'Reason (optional), e.g. I am fully booked this week.';
  static const cancelRequestTitle = 'Cancel this request?';
  static const markDoneTitle = 'Mark this job as done?';
  static const keepIt = 'Keep it';
  static String jobStatusChanged(String status) => switch (status) {
        JobStatus.accepted => 'Accepted. The customer is told.',
        JobStatus.declined => 'Declined. The customer is told.',
        JobStatus.cancelled => 'Request cancelled.',
        _ => 'Marked as done.',
      };

  // D1 Settings and edit profile
  static const settings = 'Settings';
  static const account = 'Account';
  static String roleLabel(String role) => switch (role) {
        UserRole.worker => 'Worker',
        UserRole.admin => 'Admin',
        _ => 'Customer',
      };
  static const myServices = 'My services';
  static const stopOfferingServices = 'Stop offering services';
  static const stopOfferingServicesHint = 'Use Kuzu Help only to find workers';
  static const stopOfferingServicesMessage = "Customers won't see your worker profile any more. "
      "To offer your services again later, open Settings and tap 'Become a worker'.";
  static const onlyWantToFindWorkers = 'I only want to find workers';
  static const becomeWorkerHint = 'Offer your skills and get customers';
  static const becomeWorkerMessage =
      "You'll set up your worker profile next. Our team checks it before customers can see you.";
  static const logoutConfirm = 'Log out of Kuzu Help?';
  static const cancel = 'Cancel';
  static const continueLabel = 'Continue';
  static const emailCantChange = "Used to log in. It can't be changed here.";
  static const profileSaved = 'Your profile is saved';
  static const deleteAccount = 'Delete account';
  static const deleteAccountHint = 'Remove your account and details for good';
  static const deleteAccountTitle = 'Delete your account?';
  static const deleteAccountMessage =
      'Your profile, photo, reviews and reports are deleted for good. If you offer services, '
      "your worker profile and documents are deleted too. This can't be undone.";
  static const deleteForGood = 'Delete for good';
  static const accountDeleted = 'Your account is deleted.';
  static const accountDeletionNotSetUp =
      'Deleting accounts is not set up yet: deploy supabase/functions/delete-account in Supabase.';

  // Notifications (the bell on each home screen)
  static const notifications = 'Notifications';
  static const markAllRead = 'Mark all as read';
  static const noNotifications = "Nothing yet. We'll let you know here when something happens.";

  /// Worded here from the type and data the database saves, so they can be translated.
  /// Push notifications use the same words from supabase/functions/send-push/index.ts:
  /// change both.
  static String notificationTitle(String type, Map<String, dynamic> data) {
    String text(String key, String fallback) {
      final value = (data[key] as String?)?.trim() ?? '';
      return value.isEmpty ? fallback : value;
    }

    final rating = data['rating'] as int? ?? 0;
    return switch (type) {
      NotificationTypes.welcome => 'Welcome to Kuzu Help!',
      NotificationTypes.newUser =>
        '${text('name', 'Someone')} joined as a ${roleLabel(text('role', UserRole.customer)).toLowerCase()}',
      NotificationTypes.workerSubmitted => '${text('name', 'A worker')} is waiting for approval',
      NotificationTypes.workerResubmitted => '${text('name', 'A worker')} asks to be checked again',
      NotificationTypes.reportNew => 'New report about ${text('worker_name', 'a worker')}',
      NotificationTypes.workerApproved => approvedTitle,
      NotificationTypes.workerRejected => rejectedTitle,
      NotificationTypes.reviewNew => 'A customer rated you ${starsLabel(rating)}',
      NotificationTypes.reviewUpdated => 'A customer changed their rating to ${starsLabel(rating)}',
      NotificationTypes.contact => 'A customer is getting in touch',
      NotificationTypes.reportUpdated => 'Update on your report about ${text('worker_name', 'a worker')}',
      NotificationTypes.accountDeactivated => deactivatedTitle,
      NotificationTypes.accountReactivated => 'Your account is active again',
      NotificationTypes.reviewReply => '${text('worker_name', 'The worker')} replied to your review',
      NotificationTypes.jobNew => 'New job request from ${text('customer_name', 'a customer')}',
      NotificationTypes.jobAccepted => '${text('worker_name', 'The worker')} accepted your job request',
      NotificationTypes.jobDeclined => "${text('worker_name', 'The worker')} can't take your job",
      NotificationTypes.jobCancelled => '${text('customer_name', 'The customer')} cancelled their job request',
      NotificationTypes.jobCompleted => data['by'] == 'worker'
          ? '${text('worker_name', 'The worker')} marked your job as done'
          : '${text('customer_name', 'The customer')} marked the job as done',
      _ => appName,
    };
  }

  static String notificationBody(String type, Map<String, dynamic> data) {
    final note = (data['note'] as String? ?? data['reason'] as String? ?? '').trim();
    return switch (type) {
      NotificationTypes.welcome => data['role'] == UserRole.worker
          ? 'Set up your worker profile. Our team checks it before customers can see you.'
          : 'Choose a service to find trusted local workers near you.',
      NotificationTypes.newUser => data['email'] as String? ?? '',
      NotificationTypes.workerSubmitted => 'They sent their documents. Tap to check them.',
      NotificationTypes.workerResubmitted => 'They have fixed their details. Tap to check them.',
      NotificationTypes.reportNew => reportReason(data['reason'] as String? ?? ''),
      NotificationTypes.workerApproved => approvedMessage,
      NotificationTypes.workerRejected => note.isEmpty ? rejectedMessage : note,
      NotificationTypes.reviewNew || NotificationTypes.reviewUpdated => 'Tap to see your reviews.',
      NotificationTypes.contact => data['method'] == ContactMethod.whatsapp
          ? 'They tapped WhatsApp on your profile, so check your messages.'
          : 'They tapped Call on your profile, so expect a phone call.',
      NotificationTypes.reportUpdated => switch (data['status']) {
          'reviewed' => 'Our team has looked into it. Thank you for telling us.',
          'closed' => 'Our team has closed it. Thank you for telling us.',
          _ => 'Our team is looking into it.',
        },
      NotificationTypes.accountDeactivated => note.isEmpty ? deactivatedMessage : note,
      NotificationTypes.accountReactivated => 'You can use Kuzu Help again.',
      NotificationTypes.reviewReply => 'Tap to read it.',
      NotificationTypes.jobNew => [
          if (data['category'] case final String category) category,
          'Tap to see the job and reply.',
        ].join(' · '),
      NotificationTypes.jobAccepted => note.isEmpty ? "They'll call you on the number you gave." : note,
      NotificationTypes.jobDeclined => note.isEmpty ? 'Try another worker for this job.' : note,
      NotificationTypes.jobCompleted => data['by'] == 'worker' ? 'How did it go? Leave a review.' : '',
      _ => '',
    };
  }

  static String timeAgo(DateTime time, {DateTime? now}) {
    final ago = (now ?? DateTime.now()).difference(time);
    if (ago.inMinutes < 1) return 'Just now';
    if (ago.inHours < 1) return '${ago.inMinutes} min ago';
    if (ago.inDays < 1) return ago.inHours == 1 ? '1 hour ago' : '${ago.inHours} hours ago';
    if (ago.inDays < 7) return ago.inDays == 1 ? '1 day ago' : '${ago.inDays} days ago';
    return shortDate(time);
  }

  // Shared
  static const retry = 'Retry';
  static const genericError = 'Something went wrong. Please check your internet and try again.';
  static const logout = 'Log out';
  static const becomeWorker = 'Become a worker';

  static const _months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  static String shortDate(DateTime date) {
    final d = date.toLocal();
    return '${d.day} ${_months[d.month - 1]} ${d.year}';
  }
}
