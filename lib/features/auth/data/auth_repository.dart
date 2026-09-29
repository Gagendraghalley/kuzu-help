import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase/supabase_client.dart';

/// The only place in this feature that talks to Supabase.
/// New users confirm their email with a one-time code (build guide, Phase 2),
/// then set a password (A5) and log in with it from then on. Codes are also
/// how a forgotten password is reset.
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
  /// so logging out works offline; the server's error is ignored.
  Future<void> signOut() async {
    try {
      await _db.auth.signOut();
    } on AuthException {
      // Already logged out on this phone.
    }
  }
}

final authRepositoryProvider = Provider<AuthRepository>((ref) => AuthRepository(ref.watch(supabaseProvider)));
