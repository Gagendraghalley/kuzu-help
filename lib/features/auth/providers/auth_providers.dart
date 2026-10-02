import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show AuthException;

import '../../../core/constants/app_constants.dart';
import '../../../core/router/route_names.dart';
import '../../../core/router/start_route.dart';
import '../../notifications/data/push_repository.dart';
import '../../profile/data/profile_repository.dart';
import '../../profile/providers/profile_providers.dart';
import '../../worker/data/worker_repository.dart';
import '../data/auth_repository.dart';

// Riverpod providers: the role chosen on the Welcome screen, the code request,
// where the splash sends each user, and the login actions.
// Screens watch these; these call the repositories.

/// The role picked on Welcome (A2): UserRole.customer or UserRole.worker to
/// sign up (UserRole.player from a ground), or null for "Already have an
/// account? Log in".
final chosenRoleProvider = StateProvider<String?>((ref) => null);

/// What was sent from the login screen (A3), needed again to verify or resend (A4).
final otpRequestProvider = StateProvider<OtpRequest?>((ref) => null);

/// The role picked on Welcome by someone who signed up with 'Continue with
/// Google' or 'Continue with Apple' (A3), until the splash (A1) has given it
/// to their account. Null when they logged in that way.
final socialSignUpRoleProvider = StateProvider<String?>((ref) => null);

/// The name Apple shared on someone's first 'Continue with Apple' (A3), until
/// the splash (A1) has put it on their profile.
final appleNameProvider = StateProvider<String?>((ref) => null);

/// Where a visitor tapped 'Log in to book' (a ground's booking screen). Once
/// they have logged in (and set a password, if new), the splash (A1) opens
/// it over their home screen.
final afterLoginRouteProvider = StateProvider<String?>((ref) => null);

/// A1: the route to open when the app starts or the user logs in.
final startRouteProvider = FutureProvider.autoDispose<String>((ref) async {
  final auth = ref.watch(authRepositoryProvider);
  if (!auth.isLoggedIn) return startRouteFor(null);

  final profiles = ref.watch(profileRepositoryProvider);
  var profile = await profiles.getMyProfile();
  // An account without a profiles row (made before the database was set
  // up, or its row went missing): make it now, as signing up would have.
  if (profile == null) {
    await profiles.ensureMyProfile();
    profile = await profiles.getMyProfile();
  }
  if (profile == null) {
    throw StateError('No profiles row for this user. Have supabase/schema.sql and updates.sql been run?');
  }
  // Blacklisted by an admin: nothing else, whatever else is unfinished.
  if (!profile.isActive) return Routes.deactivated;
  // Signed up for another service with an email that has an account: now
  // they've entered the code, that service is added to it (role delegation).
  final request = ref.read(otpRequestProvider);
  if (request != null && request.addsToAccount && !profile.hasRole(request.role!)) {
    await profiles.addRole(request.role!);
    ref.invalidate(myProfileProvider); // screens read the new roles
    profile = (await profiles.getMyProfile())!;
  }
  // Signed up with Apple: the database made the profile without a name.
  final appleName = ref.read(appleNameProvider);
  if (appleName != null) {
    await profiles.setMyNameIfEmpty(appleName);
    ref.read(appleNameProvider.notifier).state = null;
    ref.invalidate(myProfileProvider);
    profile = (await profiles.getMyProfile())!;
  }
  // Signed up with Google or Apple: the database made a new account a
  // customer, so it now takes the role they picked (claim_signup_role). An
  // account that was there already gets home services or sports grounds
  // added, as above.
  final socialRole = ref.read(socialSignUpRoleProvider);
  if (socialRole != null) {
    if (socialRole == UserRole.worker || socialRole == UserRole.player) {
      await profiles.claimSignUpRole(socialRole);
    }
    if (UserRole.addable.contains(socialRole) && !(await profiles.getMyProfile())!.hasRole(socialRole)) {
      await profiles.addRole(socialRole);
    }
    ref.read(socialSignUpRoleProvider.notifier).state = null;
    ref.invalidate(myProfileProvider);
    profile = (await profiles.getMyProfile())!;
  }
  // A5 next: every new user, and anyone who has just used 'Forgot password?'.
  // Except admins (made in the SQL editor): they may log in with an email code
  // alone, and can set a password in Settings. And except Google and Apple
  // accounts, which log in that way; they too can set a password in Settings.
  final resettingPassword = ref.read(otpRequestProvider)?.isPasswordReset ?? false;
  final needsPassword = !auth.hasPassword && !auth.usesGoogle && !auth.usesApple;
  if ((needsPassword || resettingPassword) && profile.role != UserRole.admin) {
    return Routes.setPassword;
  }
  if (profile.role != UserRole.worker) return startRouteFor(profile);

  final progress = await ref.watch(workerRepositoryProvider).getMyProgress();
  return startRouteFor(profile, worker: progress);
});

/// A3–A5 actions. Screens call these and show their own loading and error state.
final authActionsProvider = Provider<AuthActions>((ref) => AuthActions(ref));

class AuthActions {
  AuthActions(this._ref);
  final Ref _ref;

  AuthRepository get _repo => _ref.read(authRepositoryProvider);

  /// A3: email a code, to sign up (a role was picked on Welcome; include the
  /// name) or, with no role, for 'Forgot password?'. A4 checks it.
  /// Signing up for home services or sports grounds with an email that has
  /// an account is fine: the code logs them in, and the splash adds that
  /// service to the account (UserRole.addable). Throws
  /// [AccountProblem.alreadyRegistered] for a worker sign-up with such an
  /// email: they log in and offer services from Settings.
  Future<void> sendCode({required String email, String? fullName}) async {
    final role = _ref.read(chosenRoleProvider);
    final address = email.trim().toLowerCase();
    final registered = role != null && await _repo.isEmailRegistered(address);
    if (registered && !UserRole.addable.contains(role)) throw AccountProblem.alreadyRegistered;
    final request = OtpRequest(
      email: address,
      fullName: role == null || registered ? null : fullName?.trim(),
      role: role,
      addsToAccount: registered,
    );
    await _send(request);
    _ref.read(otpRequestProvider.notifier).state = request;
  }

  /// A4 'Resend code'.
  Future<void> resendCode() => _send(_ref.read(otpRequestProvider)!);

  /// A4: on success the router takes the user on (see app_router.dart).
  Future<void> verifyCode(String code) =>
      _repo.verifyOtp(email: _ref.read(otpRequestProvider)!.email, code: code);

  /// A3: on success the router takes the user on (see app_router.dart).
  /// Throws [AccountProblem.noAccount] when no account uses [email].
  Future<void> logIn({required String email, required String password}) async {
    _forgetCodeRequest(); // an unfinished reset shouldn't ask for a new password
    final address = email.trim().toLowerCase();
    try {
      await _repo.signInWithPassword(email: address, password: password);
    } on AuthException catch (e) {
      // Supabase says the same for a wrong password and an unknown email.
      if (e.code == 'invalid_credentials' && !await _repo.isEmailRegistered(address)) {
        throw AccountProblem.noAccount;
      }
      rethrow;
    }
  }

  /// A3 'Continue with Google', to sign up (a role was picked on Welcome) or
  /// log in. Google's account picker opens; the first time, the account is
  /// made then and the splash (A1) gives it the role. Returns false when the
  /// picker is closed. On success the router takes the user on.
  /// Logging in (no role picked) throws [AccountProblem.noAccount] for a
  /// Google account whose email no account uses, and makes none.
  Future<bool> continueWithGoogle() =>
      _continueWith((beforeSignIn) => _repo.signInWithGoogle(beforeSignIn: beforeSignIn));

  /// A3 'Continue with Apple' (iPhones), the same way with Apple's sheet. The
  /// first time, the splash also gives the account the name Apple shared.
  Future<bool> continueWithApple() => _continueWith((beforeSignIn) => _repo.signInWithApple(
      beforeSignIn: beforeSignIn, onName: (name) => _ref.read(appleNameProvider.notifier).state = name));

  Future<bool> _continueWith(
      Future<bool> Function(Future<void> Function(String? email)? beforeSignIn) signIn) async {
    _forgetCodeRequest();
    final role = _ref.read(chosenRoleProvider);
    // Set before signing in: the splash starts as soon as they're logged in.
    _ref.read(socialSignUpRoleProvider.notifier).state = role;
    var signedIn = false;
    try {
      // Logging in only goes into an account that's there. Otherwise a new
      // Google or Apple account would be made a customer without them ever
      // choosing how they'll use Kuzu Help: they sign up from Welcome instead.
      return signedIn = await signIn(role == null ? _mustHaveAccount : null);
    } finally {
      if (!signedIn) _forgetCodeRequest();
    }
  }

  Future<void> _mustHaveAccount(String? email) async {
    if (email == null || !await _repo.isEmailRegistered(email.trim().toLowerCase())) {
      throw AccountProblem.noAccount;
    }
  }

  /// A5. The screen then sends the user on through the splash (A1).
  Future<void> setPassword(String password) async {
    await _repo.setPassword(password);
    _forgetCodeRequest(); // any reset is done
  }

  Future<void> signOut() async {
    _forgetCodeRequest();
    // This phone stops getting the user's push notifications; the next user
    // to log in registers it again.
    await _ref.read(pushRepositoryProvider).unregister();
    _ref.invalidate(pushRegistrationProvider);
    return _repo.signOut();
  }

  /// Also forgets a Google or Apple sign-up's role and name, so they can't go
  /// to another account.
  void _forgetCodeRequest() {
    _ref.read(otpRequestProvider.notifier).state = null;
    _ref.read(socialSignUpRoleProvider.notifier).state = null;
    _ref.read(appleNameProvider.notifier).state = null;
  }

  /// For an account that exists, a plain log-in code: no new user.
  Future<void> _send(OtpRequest request) => _repo.sendOtp(
      email: request.email, fullName: request.fullName, role: request.addsToAccount ? null : request.role);
}

/// Sign-up and log-in problems the login screen (A3) explains itself.
enum AccountProblem implements Exception {
  /// Signing up as a worker with an email that already has an account: log
  /// in instead.
  alreadyRegistered,

  /// Logging in with an email no account uses, typed or from Google or
  /// Apple: sign up instead.
  noAccount,
}

/// The email a code was sent to, plus the name and role for a sign-up.
class OtpRequest {
  final String email;
  final String? fullName;
  final String? role;

  /// The email has an account: the code logs them in, then [role] is added to it.
  final bool addsToAccount;

  const OtpRequest({required this.email, this.fullName, this.role, this.addsToAccount = false});

  /// Codes without a role come from 'Forgot password?' and end on A5.
  bool get isPasswordReset => role == null;
}
