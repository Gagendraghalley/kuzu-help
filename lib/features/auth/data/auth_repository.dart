import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/config/env.dart';
import '../../../core/supabase/supabase_client.dart';

/// The only place in this feature that talks to Supabase.
/// New users confirm their email with a one-time code (build guide, Phase 2),
/// then set a password (A5) and log in with it from then on. Codes are also
/// how a forgotten password is reset. Or they continue with Google, or with
/// Apple on iPhones, which need neither.
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

  /// 'Continue with Apple' is offered on iPhones only: App Review asks for it
  /// there next to Google (guideline 4.8), and Android has no Apple sheet.
  bool get canUseApple => defaultTargetPlatform == TargetPlatform.iOS;

  /// The logged-in account signs in with Google, so it needn't have a password.
  bool get usesGoogle => _providers.contains('google');

  /// The same for Apple.
  bool get usesApple => _providers.contains('apple');

  List<dynamic> get _providers => [...?_db.auth.currentUser?.appMetadata['providers'] as List?];

  /// Google and Apple put the hash of a random nonce in the ID token, and
  /// Supabase checks it against the nonce itself.
  static String _newNonce() => base64Url.encode(List.generate(32, (_) => Random.secure().nextInt(256)));
  static String _hash(String nonce) => sha256.convert(utf8.encode(nonce)).toString();

  /// Google Sign-In is set up once per run of the app, with one nonce.
  static final _nonce = _newNonce();
  Future<void>? _googleReady;

  Future<void> _setUpGoogle() {
    final ids = Env.googleClientIds!;
    return _googleReady ??= GoogleSignIn.instance.initialize(
      clientId: ids.iosClientId,
      serverClientId: ids.webClientId,
      nonce: _hash(_nonce),
    );
  }

  /// Shows Google's account picker, then logs in with the account picked. The
  /// first time, Supabase makes the account and the database its profile,
  /// named as on Google (handle_new_user). [beforeSignIn] gets the account's
  /// email first, and can stop it by throwing: then nothing is made and the
  /// picker forgets the account. Returns false when the picker is closed. On
  /// success Supabase saves the session and [authChanges] fires.
  Future<bool> signInWithGoogle({Future<void> Function(String? email)? beforeSignIn}) async {
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
    if (beforeSignIn != null) {
      try {
        await beforeSignIn(account.email);
      } catch (_) {
        // So the picker asks again next time, and another account can be picked.
        await GoogleSignIn.instance.signOut().catchError((_) {});
        rethrow;
      }
    }
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

  /// Shows Apple's sign-in sheet, then logs in with that Apple ID. The first
  /// time, Supabase makes the account and the database its profile, without a
  /// name: Apple shares the name only then, and not in the ID token, so
  /// [onName] gets it before Supabase logs in. [beforeSignIn] is as for
  /// Google. Returns false when the sheet is closed. On success Supabase saves
  /// the session and [authChanges] fires.
  Future<bool> signInWithApple({
    required void Function(String fullName) onName,
    Future<void> Function(String? email)? beforeSignIn,
  }) async {
    final nonce = _newNonce();
    final AuthorizationCredentialAppleID credential;
    try {
      credential = await SignInWithApple.getAppleIDCredential(
        scopes: [AppleIDAuthorizationScopes.email, AppleIDAuthorizationScopes.fullName],
        nonce: _hash(nonce),
      );
    } on SignInWithAppleAuthorizationException catch (e) {
      if (e.code == AuthorizationErrorCode.canceled) return false;
      rethrow;
    }
    final idToken = credential.identityToken;
    if (idToken == null) throw const AuthException('Apple sent no ID token');
    // Apple puts the email in the credential only the first time; the token has it every time.
    await beforeSignIn?.call(credential.email ?? _emailIn(idToken));
    final name = [credential.givenName, credential.familyName]
        .map((part) => part?.trim() ?? '')
        .where((part) => part.isNotEmpty)
        .join(' ');
    if (name.isNotEmpty) onName(name);
    await _db.auth.signInWithIdToken(provider: OAuthProvider.apple, idToken: idToken, nonce: nonce);
    return true;
  }

  /// The email in an ID token, or null. Only read here: Supabase checks the
  /// token's signature when it logs in with it.
  static String? _emailIn(String idToken) {
    try {
      final payload = utf8.decode(base64Url.decode(base64Url.normalize(idToken.split('.')[1])));
      return (jsonDecode(payload) as Map<String, dynamic>)['email'] as String?;
    } on Object {
      return null;
    }
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
