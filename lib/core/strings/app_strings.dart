import '../constants/app_constants.dart';
import '../location/location_service.dart';
import '../utils/bhutan_time.dart';
import '../utils/price_utils.dart';

/// ALL display text lives here so Dzongkha can be added later
/// without rewriting screens.
class AppStrings {
  static const appName = 'Kuzu Help';

  // Welcome (A2)
  static const welcomeTitle = 'Local help you can trust';
  static const tagline = 'Book verified workers and sports grounds near you, all in one app.';
  static const trustVerified = 'Verified';
  static const trustReviews = 'Real reviews';
  static const trustNearby = 'Near you';
  static const whatToDo = 'What would you like to do?';
  static const needService = 'Find a service';
  static const needServiceHint = 'Plumbers, electricians, carpenters and more';
  static const browseGrounds = 'Book a ground';
  static const browseGroundsHint = 'Futsal and football. No account needed to look';
  static const offerService = 'Offer your services';
  static const offerServiceHint = 'Join as a worker and get more customers';
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
  static String signingUpAs(String role) => switch (role) {
        UserRole.worker => 'You are signing up to offer your services.',
        UserRole.player => 'You are signing up to book sports grounds.',
        _ => 'You are signing up to find workers.',
      };
  static const newHereCreateAccount = 'New to Kuzu Help? Create an account';
  static const continueWithGoogle = 'Continue with Google';
  static const orUseEmail = 'or use your email';
  static const googleSignInFailed =
      "Couldn't sign in with Google. Please try again, or use your email.";
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
      '"$needService" or "$offerService" to sign up.';
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
  static const searchDzongkhags = 'Type a dzongkhag or town';
  static String nothingMatches(String typed) => 'Nothing matches "$typed".';
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

  // C1 Customer home: the three services
  static const homeServices = 'Home services';
  static const sportsGrounds = 'Sports grounds';
  static const partyDining = 'Party & dining';
  static const comingSoon = 'Soon';
  static const bookAGround = 'Book a futsal or football ground near you';
  static const planAParty = 'Plan a farewell, birthday or office party';
  static const partyComingSoon = 'Coming soon: book restaurants and bars for farewells, birthdays, '
      'office parties and more, right here in Kuzu Help.';

  // Sports grounds: finding one
  static const allSports = 'All sports';
  static String sportLabel(String sport) => switch (sport) {
        Sport.futsal => 'Futsal',
        Sport.football => 'Football',
        Sport.basketball => 'Basketball',
        Sport.badminton => 'Badminton',
        _ => 'Other',
      };
  static String noVenuesYet({required bool everywhere}) => everywhere
      ? 'No sports grounds yet – check back soon'
      : 'No sports grounds in this area yet – check back soon';
  static String noVenuesForSport(String sport) =>
      'No ${sportLabel(sport).toLowerCase()} grounds here yet. Try "$allSports".';
  static const searchGrounds = 'Search grounds by name or place';
  static const typeToSearchGrounds = 'Type at least 2 letters of a ground\'s name, town or dzongkhag.';
  static String noVenuesNamed(String query) => 'No sports grounds match "$query" yet.';
  static String fromPricePerHour(int price) => 'From ${PriceUtils.nu(price)} an hour'; // read aloud
  static const priceFrom = 'From';
  static const perHour = '/hour';
  static const instantBooking = 'Instant booking';
  static const myBookings = 'My bookings';
  static const venuesCheckedNote = 'Every ground is checked by our team before it appears here.';

  // Sports grounds: how far away, and directions
  static const nearestFirst = 'Nearest first';
  static const showDistance = 'How far is it from me?';
  static const distancePrompt = 'See how far each ground is';
  static const distancePromptHint = 'Tap to use your location';
  static String distanceAway(double km) => '${_distance(km)} away';
  static String distanceFromYou(double km) => 'About ${_distance(km)} from you in a straight line';
  static String _distance(double km) {
    final metres = (km * 20).round() * 50; // to the nearest 50 m
    if (metres < 1000) return '${metres < 50 ? 50 : metres} m';
    return km < 10 ? '${km.toStringAsFixed(1)} km' : '${km.round()} km';
  }
  static const directions = 'Directions in Google Maps';
  static const directionsShort = 'Directions';
  static const cannotOpenMaps = 'Could not open Google Maps on this device.';
  static String locationProblem(LocationProblem problem) => switch (problem) {
        LocationProblem.serviceOff => 'Location is off on this phone. Turn it on, then try again.',
        LocationProblem.denied => 'Allow Kuzu Help to use your location, then try again.',
        LocationProblem.deniedForever => 'Kuzu Help may not use your location. Allow it in Settings.',
        LocationProblem.unavailable => 'Could not find where you are. Please try again in a moment.',
        LocationProblem.outsideBhutan => "You don't seem to be in Bhutan, so distances to grounds aren't shown.",
      };
  static const openSettings = 'Settings';

  // Sports grounds: a venue's page
  static const venueNotListed = 'This ground is not taking bookings right now.';
  static const book = 'Book';
  static String groundPrice(int price, {int? eveningPrice, required int eveningFrom}) => [
        '${PriceUtils.nu(price)}$perHour',
        if (eveningPrice != null) '${PriceUtils.nu(eveningPrice)}$perHour at night, from ${hourLabel(eveningFrom)}',
      ].join(' · ');
  static const dayPrice = 'Day';
  static String nightPriceFrom(int hour) => 'Night, from ${hourLabel(hour)}';
  static const everyDay = 'Every day';
  /// 'Mon', or 'Mon – Fri' (0 = Sunday).
  static String weekdays(int from, int to) =>
      from == to ? weekdayName(from) : '${weekdayName(from)} – ${weekdayName(to)}';
  static String hoursRange(int openHour, int closeHour) => '${hourLabel(openHour)} – ${hourLabel(closeHour)}';

  /// A time on the timetable, as short as reads clearly: '6 – 8 pm',
  /// '12 – 2 pm', but '10 pm – 12 am' and '11 am – 1 pm'.
  static String hoursShort(int startHour, int endHour) {
    final start = hourLabel(startHour);
    final end = hourLabel(endHour);
    final sameHalf = start.endsWith(end.substring(end.length - 2));
    return sameHalf ? '${start.substring(0, start.length - 3)} – $end' : '$start – $end';
  }
  static const indoor = 'Indoor';
  static const outdoor = 'Outdoor';
  static const floodlights = 'Floodlights';
  static const cancelling = 'Cancelling';
  static String freeCancelNote(int hours) => hours == 0
      ? 'You can cancel for free until your booking starts.'
      : 'You can cancel for free up to ${hours == 1 ? '1 hour' : '$hours hours'} before your booking starts.';
  static const confirmedAtOnce = 'This ground confirms bookings at once.';
  static const confirmedByVenue = 'The ground manager confirms each booking, usually within a few hours. '
      "Requests they don't answer in 12 hours are cancelled, so the time is free again.";
  static const yourPublicVenue = 'This is how customers see your ground.';
  static const reviewVenueAfterPlaying = 'You can review this ground after you have played there.';
  static const noVenueReviews = 'No reviews yet.';
  static const howWasTheGround = 'How was the ground?';
  static const venueReviewCommentHint = 'Was the ground good? Was it ready on time? Would you play there again?';

  // Sports grounds: booking
  static const bookGround = 'Book a time';
  static const chooseDay = 'Choose a day';
  static const bookUpToAWeek = 'You can book up to one week ahead.';
  static const today = 'Today';
  static const tomorrow = 'Tomorrow';
  static const chooseTime = 'Choose a time';
  static const closedThisDay = 'The ground has no times on this day. Please choose another.';
  static const noFreeTimes = 'No free times left on this day. Please choose another day.';
  /// A time someone has: '6 pm – 8 pm · Booked' once the ground manager has
  /// confirmed it, '· On hold' while it waits for their answer, '· Not
  /// available' when it runs into another booking or the manager closed it.
  static String takenSlot(int startHour, int endHour, {required bool exact, required bool confirmed, bool regular = false}) =>
      '${hoursRange(startHour, endHour)} · '
      '${!exact ? 'Not available' : regular ? regularBooking : confirmed ? 'Booked' : 'On hold'}';
  static const takenTimesNote = 'Booked: confirmed by the ground manager. Regular booking: the same team plays '
      "then every week. On hold: someone has asked for it and is waiting for the manager's answer. Not "
      'available: it runs into a booked time, or the manager has closed it.';
  static const createAccountToBook = 'Create a free account to book';
  static const logInToBook = 'I have an account: log in';
  static const logInToBookNote = 'First time here? Create a free account with your name and email: we send a '
      "code to your email, then you choose a password. You'll come straight back here to book.";
  static const chooseATime = 'Please choose a time';
  static const yourBooking = 'Your booking';
  static const teamName = 'Team name (optional)';
  static const teamNameHint = 'e.g. Changzamtog FC';
  static const playersCount = 'Number of players (optional)';
  static const invalidPlayers = 'Please enter a number from 1 to 30';
  static const howWillYouPay = 'How will you pay?';
  static String paymentLabel(String method) => switch (method) {
        PaymentMethod.mbob => 'mBoB transfer',
        PaymentMethod.mpay => 'mPay transfer',
        _ => 'Pay at the ground',
      };
  static const howToPayVenue = 'How to pay this ground';
  static const askVenueHowToPay = 'Ask the ground manager where to send the money.';
  static const journalNumber = 'Journal number (optional)';
  static const journalNumberHint = 'From your receipt, once you have paid';
  static const bookingNote = 'Message for the ground manager (optional)';
  static const bookingNoteHint = 'e.g. We need bibs for 10 players.';
  static const sendBookingRequest = 'Send booking request';
  static String bookFor(int price) => 'Book for ${PriceUtils.nu(price)}';
  static const bookingRequestSent = "Booking request sent. We'll let you know when the ground manager answers.";
  static const bookedNow = 'Booked! You can find it under My bookings.';
  static const slotTaken = 'Sorry, someone has just booked this time. Please choose another.';
  static const tooManyWaiting =
      'You have 3 bookings waiting for an answer. Wait for a ground to reply, or cancel one, then book again.';
  static const groundNotBookable = "This ground isn't taking bookings right now.";
  static const timeNotBookable = "This time can't be booked. Please choose another.";
  static const ownGround = 'This is your own ground. Block the time from your bookings instead.';

  // Sports grounds: My bookings (customers)
  static const upcoming = 'Upcoming';
  static const past = 'Past';
  static String noBookings({required bool upcoming}) =>
      upcoming ? 'No bookings yet. Choose a sports ground and book a time.' : 'Nothing here yet.';
  /// [expired]: cancelled because the ground manager didn't answer in time.
  static String bookingStatusLabel(String status, {bool expired = false}) => switch (status) {
        BookingStatus.confirmed => 'Confirmed',
        BookingStatus.rejected => 'Not accepted',
        BookingStatus.cancelled when expired => 'Expired',
        BookingStatus.cancelled => 'Cancelled',
        BookingStatus.completed => 'Played',
        BookingStatus.noShow => 'No-show',
        _ => 'Waiting for the ground',
      };
  static String paymentStatusLabel(String status) => switch (status) {
        PaymentStatus.depositClaimed => 'Advance sent',
        PaymentStatus.paid => 'Paid',
        _ => 'Not paid yet',
      };
  static const messageFromVenue = 'Message from the ground';
  static const whenLabel = 'When';
  static const whereLabel = 'Where';
  static const priceLabel = 'Price';
  static const paymentTitle = 'Payment';
  static const teamLabel = 'Team';
  static const playersLabel = 'Players';
  static const noteLabel = 'Note';
  static const cancelBooking = 'Cancel booking';
  static const cancelBookingTitle = 'Cancel this booking?';
  static String lateCancelWarning(int hours) =>
      'Free cancellation ended ${hours == 1 ? '1 hour' : '$hours hours'} before the start. '
      'The ground may still ask you to pay.';
  static const addJournalNumber = 'Add journal number';
  static const journalNumberTitle = 'Journal number of your payment';
  static const journalNumberSaved = 'Saved. The ground manager can see it.';
  static const enterJournalNumber = 'Please enter the journal number';
  static const openVenuePage = 'Open ground page';

  // Sports grounds: running a venue (its manager, and admins)
  static const myVenues = 'My grounds';
  static const noVenueToManage =
      "You don't run a ground at the moment. The Kuzu Help team adds you to the ground you run.";
  static const addVenue = 'Register a ground';
  static const registerVenue = 'Register ground';
  static const editVenue = 'Edit ground';
  static const venueName = 'Ground name';
  static const venueNameHint = 'e.g. Changlimithang Futsal Arena';
  static const enterVenueName = 'Please enter the name of the ground';
  static const venueAddress = 'Address or landmark (optional)';
  static const venueAddressHint = 'e.g. Behind the Changlimithang stadium';
  static const mapLocation = 'Location on the map (optional)';
  static const mapLocationHint = 'Customers see how far away the ground is and get directions. Stand at the '
      'ground and use your location, or paste its link from Google Maps (Share, then Copy link).';
  static const notOnMapYet = 'Not on the map yet';
  static const onTheMap = 'On the map';
  static const useMyLocation = 'Use my current location';
  static const pasteMapsLink = 'Paste a Google Maps link';
  static const mapsLinkTitle = 'Google Maps link';
  static const mapsLinkHint = 'https://maps.app.goo.gl/... or 27.4728, 89.6390';
  static const useLink = 'Use this link';
  static const pasteLinkFirst = 'Paste the link from Google Maps here.';
  static const mapsLinkNoPlace = "That link doesn't show a place. In Google Maps, drop a pin on the ground, "
      'tap Share, then Copy link.';
  static const notInBhutan = "That place isn't in Bhutan. Check the link, or stand at the ground and use your "
      'location.';
  static const checkOnMap = 'Check on Google Maps';
  static const removeFromMap = 'Take off the map';
  static const venuePhone = 'Phone for bookings';
  static const venueWhatsapp = 'WhatsApp number (optional)';
  static const venueAbout = 'About the ground (optional)';
  static const venueAboutHint = 'e.g. Two covered futsal courts, with changing rooms and parking.';
  static const coverPhoto = 'Cover photo (optional)';
  static const coverPhotoHint = 'A clear photo of your ground helps customers choose it.';
  static const autoConfirm = 'Confirm bookings automatically';
  static const autoConfirmHint = 'Customers are booked at once. Turn off to accept or reject each request.';
  static const freeCancellation = 'Free cancellation';
  static String freeCancelOption(int hours) =>
      hours == 0 ? 'Until the booking starts' : 'Up to ${hours == 1 ? '1 hour' : '$hours hours'} before';
  static const cancellationRules = 'Cancellation rules (optional)';
  static const cancellationRulesHint = 'e.g. Late cancellations pay half the price.';
  static const paymentInfo = 'How to pay an advance (optional)';
  static const paymentInfoHint = 'e.g. mBoB 200123456 (Tashi Futsal)';
  static String venueRegistered(String venue, String manager, String email, {required bool created}) => created
      ? '$venue is registered, and $manager runs it. They log in with $email and "$forgotPassword" the first time.'
      : '$venue is registered, and $manager runs it. They are told in the app.';
  static const venueSaved = 'The ground is saved';
  static String venueStatusLabel({required bool active, required bool hasManager}) =>
      !hasManager ? 'No manager yet' : active ? 'Taking bookings' : 'Paused';
  static const takingBookings = 'Taking bookings';
  static const takingBookingsHint = 'Customers can find and book this ground.';
  static const pausedHint = "Paused: customers can't see this ground or book it.";
  static const notVisibleYet = 'Not visible yet';
  static const notVisibleNoGrounds =
      "Customers and visitors can't see this ground yet: add its type, price and timings, and it appears.";
  static const timings = 'Timings';
  static const noTimingsYet = "No timings yet: customers can't book until you add them.";
  static const typeAndPriceFirst = "First add the ground's type and price, then its timings.";
  static const addTypeAndPrice = 'Add type and price';
  static const setTimings = 'Set timings';
  static const timingsHint = 'Add the times people can book on each day, Monday to Sunday: as many as you like, '
      'e.g. 6 pm – 8 pm and 8 pm – 10 pm. A day with no times is closed. Customers book one whole time.';
  static const addTime = 'Add a time';
  static const removeTime = 'Remove this time';
  static const copyMondayToAll = "Copy Monday's times to every day";
  static const saveTimings = 'Save timings';
  static const timingsSaved = "Timings saved. Everyone sees them on your ground's page.";
  static const bookings = 'Bookings';
  static String requestsToAnswer(int n) =>
      n == 0 ? 'No new requests' : n == 1 ? '1 request to answer' : '$n requests to answer';
  static const seePublicVenue = 'View my public page';
  static const typeAndPrice = 'Type and price';
  static const sport = 'Type of ground';
  static const groundFormat = 'Format (optional)';
  static const groundFormatHint = 'e.g. 5-a-side';
  static const groundSurface = 'Surface (optional)';
  static const groundSurfaceHint = 'e.g. Artificial turf';
  static const indoorLabel = 'Indoor (covered)';
  static const floodlightsLabel = 'Floodlights for evening games';
  static const pricePerHour = 'Price per hour';
  static const nightPriceLabel = 'Different price at night';
  static const nightPriceHint = 'e.g. more when the floodlights are on. Off: the same price all day.';
  static const eveningPrice = 'Night price per hour';
  static const eveningFrom = 'Night price starts at';
  static const enterPrice = 'Please enter the price in Ngultrum';
  static const closed = 'Closed';
  static const addAtLeastOneTime = 'Please add at least one time';
  static const paused = 'Paused';
  static String weekdayName(int weekday) => const ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'][weekday];

  // Sports grounds: a venue's bookings, for its manager
  static const requests = 'Requests';
  static String noVenueBookings(String tab) => switch (tab) {
        requests => 'No requests waiting. New ones show here and under the bell.',
        upcoming => 'No upcoming bookings.',
        _ => 'Nothing here yet.',
      };
  static String blockedFor(String? reason) =>
      reason == null || reason.trim().isEmpty ? 'Blocked' : 'Blocked: ${reason.trim()}';
  static String bookedBy(String name) => name.isEmpty ? 'A customer' : name;
  static const messageFromCustomer = 'Message from the customer';
  static const yourMessage = 'Your message';
  static const confirmBooking = 'Confirm';
  static const rejectBooking = 'Reject';
  static const confirmBookingTitle = 'Confirm this booking?';
  static const confirmBookingHint = 'Message for the customer (optional), e.g. Please come 10 minutes early.';
  static const rejectBookingTitle = 'Reject this booking?';
  static const rejectBookingHint = 'Reason (optional), e.g. The ground is closed for repairs that day.';
  static const cancelBookingVenueHint = 'Reason for the customer (optional), e.g. Heavy rain has flooded the ground.';
  static const markPlayed = 'Mark as played';
  static const markNoShow = "They didn't come";
  static const markPaid = 'Mark as paid';
  static const markNotPaid = 'Mark as not paid';
  static const removeBlock = 'Remove block';
  static const removeBlockTitle = 'Remove this block?';
  static String bookingStatusChanged(String status, {bool byOwner = false}) => switch (status) {
        BookingStatus.confirmed => 'Confirmed. The customer is told.',
        BookingStatus.rejected => 'Rejected. The customer is told.',
        BookingStatus.cancelled => byOwner ? 'Cancelled. The customer is told.' : 'Booking cancelled. The ground is told.',
        BookingStatus.completed => 'Marked as played.',
        _ => 'Marked as a no-show.',
      };
  static String paymentChanged({required bool paid}) => paid ? 'Marked as paid.' : 'Marked as not paid.';
  static const addBooking = 'Add a booking';
  static const regularBooking = 'Regular booking';
  static const regularBookings = 'Regular bookings';
  static const addRegularBooking = 'Add a regular booking';
  static const everyWeek = 'Mark as regular';
  static String everyWeekHint(int weekday) => 'Held every ${weekdayName(weekday)} at this time, until you edit or '
      'remove it. Everyone sees it as a regular booking, and nobody else can book it.';
  static String everyWeekday(int weekday, int startHour, int endHour) =>
      'Every ${weekdayName(weekday)}, ${hoursRange(startHour, endHour)}';
  static const regularTimesHint = 'Held every week at the times you choose, on one day or more, until you edit or '
      'remove them. Everyone sees them as regular bookings, and nobody else can book them.';
  static const regularMoreDays = 'Plays more than once a week? Choose another day and tap its time too.';
  /// 'Add a regular booking', or 'Add 2 regular bookings' for [n] times at once.
  static String addRegularBookings(int n) => n <= 1 ? addRegularBooking : 'Add $n regular bookings';
  static String regularAdded(int weekday, int startHour, int endHour) =>
      'Regular booking added: ${everyWeekday(weekday, startHour, endHour).toLowerCase()}.';
  /// [times]: each one's everyWeekday.
  static String regularsAdded(List<String> times) =>
      'Regular bookings added: ${times.map((t) => t.toLowerCase()).join(' and ')}.';
  static const regularClash =
      'This time is taken, by another regular booking or a booking in the week ahead. Cancel that booking first, '
      'or choose another time.';
  static const regularNotATime = "This time isn't one of the ground's timings any more. Add it under Timings first.";
  static const noRegularBookings = 'None yet. For a team that plays at the same time every week: the time is held '
      'for them every week until you edit or remove it. You can also open a booking and mark it as regular.';
  static const markRegular = 'Mark as regular';
  static const markRegularTitle = 'Make this a regular booking?';
  static String markRegularMessage(String name, int weekday, int startHour, int endHour) =>
      '${bookedBy(name)} gets ${everyWeekday(weekday, startHour, endHour).toLowerCase()}, every week from now on, '
      'until you edit or remove it. Everyone sees it as a regular booking, and nobody else can book it.';
  static const editRegular = 'Edit';
  static const editRegularTitle = 'Edit regular booking';
  static const saveRegular = 'Save';
  static String regularSaved(int weekday, int startHour, int endHour) =>
      'Regular booking saved: ${everyWeekday(weekday, startHour, endHour).toLowerCase()}.';
  static const stopRegular = 'Remove regular booking';
  static const stopRegularTitle = 'Remove this regular booking?';
  static const stopRegularMessage = "The time is free for everyone to book again. They aren't told in the app.";
  static const regularStopped = 'Regular booking removed. The time is free again.';
  static const regular = 'Regular';
  static const bookingRecords = 'Booking records';
  static const bookingRecordsHint = 'Everyone who has booked, in the app, by phone or every week.';
  static const noBookingRecords = 'No one has booked yet. Everyone who books, in the app or by phone, shows here.';
  static String timesBooked(int n) => n == 1 ? 'Booked once' : 'Booked $n times';
  static String lastBooked(DateTime start) => 'Last: ${dayLabel(BhutanTime.dayOf(start))}';
  static const phoneBookingHint = "For someone who called you. It's confirmed at once, and everyone sees the "
      "time as Booked. They aren't told in the app.";
  static const callerName = 'Their name';
  static const enterCallerName = 'Please enter their name';
  static const callerPhone = 'Their mobile number (optional)';
  static const bookThisTime = 'Book this time';
  static const phoneBooked = 'Booked. Everyone sees this time as booked.';
  static const byPhone = 'By phone';
  static const cancelPhoneBookingMessage = "The time is free again. They aren't told in the app, so please let "
      'them know.';
  static const phoneBookingCancelled = 'Cancelled. The time is free again.';
  static const blockTime = 'Block time';
  static const blockTimeHint = "Customers can't book blocked time: for repairs, a tournament or a private event.";
  static const blockDay = 'Day';
  static const blockFrom = 'From';
  static const blockUntil = 'Until';
  static const blockReason = 'Reason (optional)';
  static const blockReasonHint = 'e.g. Tournament';
  static const timeBlocked = "Time blocked. Customers can't book it.";
  static const blockOverlaps = 'A booking already has some of this time. Reject or cancel it first.';
  static const blockRemoved = 'Block removed. Customers can book this time again.';

  // Admin: sports venues and the people who run them
  static const sportsVenues = 'Sports grounds';
  static const noVenuesAdded = 'No grounds yet. Register a ground together with the person who runs it.';
  static const manageVenue = 'Manage this ground';
  static const groundManager = 'Ground manager';
  static const noManagerYet = "No manager yet: customers can't book this ground until it has one.";
  static const addManager = 'Add manager';
  static const changeManager = 'Change manager';
  static const removeManager = 'Remove manager';
  static const removeManagerTitle = 'Remove this manager?';
  static const removeManagerMessage = "Customers can't book the ground until you add another manager.";
  static const managerRemoved = "Manager removed. Customers can't book this ground for now.";
  static const managerAccountHint = "We make a Kuzu Help account for this email, or use the one it has already. "
      "The first time, they open Kuzu Help, tap 'Log in', then '$forgotPassword': "
      'a code comes by email, and they choose their password.';
  static const managerName = "Manager's full name";
  static const enterManagerName = "Please enter the manager's name";
  static const managerEmail = "Manager's email";
  static const managerPhone = "Manager's mobile number (optional)";
  static const saveManager = 'Save manager';
  static String managerAdded(String name, String email, {required bool created}) => created
      ? '$name now runs this ground. Tell them to log in with $email and "$forgotPassword".'
      : '$name now runs this ground. They are told in the app.';
  static const managerNotAllowed =
      "This email is an admin's, a worker's or a deactivated account. Please use another email for the ground.";
  static const managerSetupMissing =
      'Adding managers is not set up yet: deploy supabase/functions/create-venue-manager in Supabase.';

  // Bhutan time, for bookings
  /// '6 am', '12 pm'; 0 and 24 are '12 am' (midnight).
  static String hourLabel(int hour) {
    final h = hour % 24;
    return '${h % 12 == 0 ? 12 : h % 12} ${h < 12 ? 'am' : 'pm'}';
  }

  /// A Bhutan day: 'Sat 4 Oct'.
  static String dayLabel(DateTime day) => '${weekdayName(BhutanTime.weekdayOf(day))} ${dayMonth(day)}';

  /// '4 Oct'.
  static String dayMonth(DateTime day) => '${day.day} ${_months[day.month - 1]}';

  /// 'Sat 4 Oct, 6 pm – 8 pm' in Bhutan time; both days when it runs past midnight.
  static String bookingTime(DateTime start, DateTime end) {
    final from = BhutanTime.of(start);
    final to = BhutanTime.of(end);
    final day = BhutanTime.dayOf(start);
    final endsSameDay = BhutanTime.dayOf(end) == day || (to.hour == 0 && end.difference(start).inHours <= 24);
    return endsSameDay
        ? '${dayLabel(day)}, ${hourLabel(from.hour)} – ${hourLabel(to.hour)}'
        : '${dayLabel(day)} ${hourLabel(from.hour)} – ${dayLabel(BhutanTime.dayOf(end))} ${hourLabel(to.hour)}';
  }

  // D1 Settings and edit profile
  static const settings = 'Settings';
  static const account = 'Account';
  static String roleLabel(String role) => switch (role) {
        UserRole.worker => 'Worker',
        UserRole.admin => 'Admin',
        UserRole.groundManager => 'Ground manager',
        UserRole.player => 'Player',
        _ => 'Customer',
      };

  // One account, more than one service (UserRole.addable)
  /// The service a role is for.
  static String serviceLabel(String role) => role == UserRole.player ? 'Sports grounds' : 'Home services';
  static String addingToAccount(String role) => 'This email already has a Kuzu Help account. Enter the code to '
      'log in: ${serviceLabel(role).toLowerCase()} are added to it, and you keep everything you have.';
  static String addService(String role) => 'Use this account for ${serviceLabel(role).toLowerCase()}';
  static String addServiceHint(String role) => role == UserRole.player
      ? 'Book futsal and football grounds, with the same log-in.'
      : 'Find trusted workers for jobs at home, with the same log-in.';
  static String serviceAdded(String role) => '${serviceLabel(role)} added to your account.';
  static const addGroundsNote = 'Sports grounds are a separate service from home services. Add them to this '
      'account to book: same log-in, and you keep everything you have.';
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
      NotificationTypes.venueAssigned => 'You now run ${text('venue_name', 'a ground')}',
      NotificationTypes.bookingNew => data['status'] == BookingStatus.confirmed
          ? '${text('customer_name', 'A customer')} booked ${text('ground_name', 'your ground')}'
          : 'New booking request from ${text('customer_name', 'a customer')}',
      NotificationTypes.bookingConfirmed => '${text('venue_name', 'The ground')} confirmed your booking',
      NotificationTypes.bookingRejected => "${text('venue_name', 'The ground')} can't take your booking",
      NotificationTypes.bookingCancelled => data['by'] == 'customer'
          ? '${text('customer_name', 'A customer')} cancelled their booking'
          : '${text('venue_name', 'The ground')} cancelled your booking',
      NotificationTypes.bookingExpired => "${text('venue_name', 'The ground')} didn't answer your request",
      NotificationTypes.bookingCompleted => 'How was ${text('venue_name', 'the ground')}?',
      NotificationTypes.venueReviewNew => 'A customer rated your ground ${starsLabel(rating)}',
      NotificationTypes.venueReviewUpdated =>
        'A customer changed their rating of your ground to ${starsLabel(rating)}',
      _ => appName,
    };
  }

  /// A booking notification's court and time: 'Court A · Sat 4 Oct, 6 pm – 8 pm'.
  static String _bookingNoticeTime(Map<String, dynamic> data) {
    final start = DateTime.tryParse(data['starts_at'] as String? ?? '');
    final hours = data['hours'] as int?;
    return [
      if ((data['ground_name'] as String?)?.trim() case final ground? when ground.isNotEmpty) ground,
      if (start != null && hours != null) bookingTime(start, start.add(Duration(hours: hours))),
    ].join(' · ');
  }

  static String notificationBody(String type, Map<String, dynamic> data) {
    final note = (data['note'] as String? ?? data['reason'] as String? ?? '').trim();
    return switch (type) {
      NotificationTypes.welcome => switch (data['role']) {
          UserRole.worker => 'Set up your worker profile. Our team checks it before customers can see you.',
          UserRole.player => 'Find a sports ground near you, choose a free time and book it.',
          _ => 'Choose a service to find trusted local workers near you.',
        },
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
      NotificationTypes.venueAssigned => 'Answer its bookings, and keep its type, price and timings up to date here.',
      NotificationTypes.bookingNew => [
          _bookingNoticeTime(data),
          if (data['status'] == BookingStatus.pending) 'Tap to confirm or reject.',
        ].where((part) => part.isNotEmpty).join(' · '),
      NotificationTypes.bookingConfirmed =>
        [_bookingNoticeTime(data), note].where((part) => part.isNotEmpty).join(' · '),
      NotificationTypes.bookingRejected => note.isEmpty ? 'Try another time or ground.' : note,
      NotificationTypes.bookingCancelled =>
        data['by'] == 'customer' || note.isEmpty ? _bookingNoticeTime(data) : note,
      NotificationTypes.bookingExpired =>
        'The request is cancelled, so the time is free again. Try another time or ground.',
      NotificationTypes.bookingCompleted => 'Tap to leave a review.',
      NotificationTypes.venueReviewNew || NotificationTypes.venueReviewUpdated => 'Tap to see your reviews.',
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
