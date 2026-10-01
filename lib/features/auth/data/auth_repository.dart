import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/config/env.dart';
import '../../../core/supabase/supabase_client.dart';

/// The only place in this feature that talks to Supabase.
/// New users confirm their email with a one-time code (build guide, Phase 2),
/// then set a password (A5) and log in with it from then on. Codes are also
/// how a forgotten password is reset. Or they continue with Google, which
/// needs neither.
class AuthRepository {
  final SupabaseClient _db;
  AuthRepository(this._db);

  static const _hasPasswordKey = 'has_password';

  /// Supabase keeps the session on the phone, so this stays true after a restart.
  bool get isLoggedIn => _db.auth.currentSession != null;

  /// The logged-in user's ID (profiles.id), or null.
  String? get userId => _db.auth.currentUser?.id;

  /// False until the user sets a password (A5); kept in their user metadata.
  bool get hasPassword => _db.auth.currentUser?.userMetadata?[_hasPasswordKey] == true;

  /// Whether 'Continue with Google' can be offered: config/dev.json has the
  /// Google client IDs for this phone (Env.googleClientIds).
  bool get canUseGoogle => Env.googleClientIds != null;

  /// The logged-in account signs in with Google, so it needn't have a password.
  bool get usesGoogle => [...?_db.auth.currentUser?.appMetadata['providers'] as List?].contains('google');

  /// Google Sign-In is set up once per run of the app, with one nonce: Google
  /// puts its hash in the ID token, and Supabase checks the two match.
  static final _nonce = base64Url.encode(List.generate(32, (_) => Random.secure().nextInt(256)));
  Future<void>? _googleReady;

  Future<void> _setUpGoogle() {
    final ids = Env.googleClientIds!;
    return _googleReady ??= GoogleSignIn.instance.initialize(
      clientId: ids.iosClientId,
      serverClientId: ids.webClientId,
      nonce: sha256.convert(utf8.encode(_nonce)).toString(),
    );
  }

  /// Shows Google's account picker, then logs in with the account picked. The
  /// first time, Supabase makes the account and the database its profile,
  /// named as on Google (handle_new_user). Returns false when the picker is
  /// closed. On success Supabase saves the session and [authChanges] fires.
  Future<bool> signInWithGoogle() async {
    await _setUpGoogle();
    const scopes = ['email', 'profile'];
    final GoogleSignInAccount account;
    try {
      account = await GoogleSignIn.instance.authenticate(scopeHint: scopes);
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled) return false;
      rethrow;
    }
    final idToken = account.authentication.idToken;
    if (idToken == null) throw const AuthException('Google sent no ID token');
    // Where the picker granted it already, the access token lets Supabase
    // check the ID token further. Never asks the user again for it.
    final authorization = await account.authorizationClient.authorizationForScopes(scopes);
    await _db.auth.signInWithIdToken(
      provider: OAuthProvider.google,
      idToken: idToken,
      accessToken: authorization?.accessToken,
      nonce: _nonce,
    );
    return true;
  }

  /// Fires when the user logs in or out. Not on token refreshes or password
  /// changes: the router re-checks on each event, and one arriving just as a
  /// screen closes can bring that screen back.
  Stream<void> get authChanges =>
      _db.auth.onAuthStateChange.map((state) => state.session != null).distinct();

  /// Emails a 6-digit code. Sign-ups pass [fullName] and [role]; the database
  /// creates their profile from them (supabase/schema.sql, section 3).
  /// Password resets pass neither, and fail if no account uses [email].
  Future<void> sendOtp({required String email, String? fullName, String? role}) {
    final isSignUp = role != null;
    return _db.auth.signInWithOtp(
      email: email,
      shouldCreateUser: isSignUp,
      data: isSignUp ? {'full_name': fullName, 'role': role} : null,
    );
  }

  /// On success Supabase saves the session and [authChanges] fires.
  Future<void> verifyOtp({required String email, required String code}) =>
      _db.auth.verifyOTP(type: OtpType.email, email: email, token: code);

  /// Whether a confirmed account uses [email] (supabase/updates.sql).
  /// Works before logging in.
  Future<bool> isEmailRegistered(String email) async =>
      await _db.rpc('is_email_registered', params: {'check_email': email}) as bool;

  /// On success Supabase saves the session and [authChanges] fires.
  Future<void> signInWithPassword({required String email, required String password}) async {
    await _db.auth.signInWithPassword(email: email, password: password);
  }

  /// Sets the password and records that the user has one.
  Future<void> setPassword(String password) async {
    try {
      await _db.auth.updateUser(UserAttributes(password: password, data: {_hasPasswordKey: true}));
    } on AuthException catch (e) {
      // It already is their password: a reset back to the old one, or a phone
      // whose saved login is from before they set it. Just record it.
      if (e.code != ErrorCode.samePassword.code) rethrow;
      await _db.auth.updateUser(UserAttributes(data: {_hasPasswordKey: true}));
    }
  }

  /// Supabase removes the session from the phone before telling the server,
  /// so logging out works offline; the server's error is ignored. Google's
  /// picker forgets the account too, so someone else can pick theirs.
  Future<void> signOut() async {
    if (usesGoogle && canUseGoogle) {
      try {
        await _setUpGoogle();
        await GoogleSignIn.instance.signOut();
      } catch (_) {
        // Only the picker's memory; logging out of Kuzu Help goes on.
      }
    }
    try {
      await _db.auth.signOut();
    } on AuthException {
      // Already logged out on this phone.
    }
  }
}

final authRepositoryProvider = Provider<AuthRepository>((ref) => AuthRepository(ref.watch(supabaseProvider)));
