import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

/// Values passed at build time with --dart-define-from-file=config/dev.json
class Env {
  static const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

  // Push notifications (optional; see the README). From the Firebase console:
  // Project settings -> Your apps, or the app's google-services.json.
  static const _firebaseProjectId = String.fromEnvironment('FIREBASE_PROJECT_ID');
  static const _firebaseSenderId = String.fromEnvironment('FIREBASE_MESSAGING_SENDER_ID');
  static const _firebaseAndroidAppId = String.fromEnvironment('FIREBASE_ANDROID_APP_ID');
  static const _firebaseAndroidApiKey = String.fromEnvironment('FIREBASE_ANDROID_API_KEY');
  static const _firebaseIosAppId = String.fromEnvironment('FIREBASE_IOS_APP_ID');
  static const _firebaseIosApiKey = String.fromEnvironment('FIREBASE_IOS_API_KEY');

  // Continue with Google (optional; see the README). From Google Cloud >
  // APIs & Services > Credentials: the Web client's ID, which Supabase checks
  // too, and the iOS client's ID.
  static const _googleWebClientId = String.fromEnvironment('GOOGLE_WEB_CLIENT_ID');
  static const _googleIosClientId = String.fromEnvironment('GOOGLE_IOS_CLIENT_ID');

  static void check() {
    if (supabaseUrl.isEmpty || supabaseAnonKey.isEmpty) {
      throw StateError(
        'Missing Supabase config. Run with --dart-define-from-file=config/dev.json',
      );
    }
    if (supabaseUrl.contains('YOUR-PROJECT-ID') || supabaseAnonKey.startsWith('YOUR-')) {
      throw StateError(
        'config/dev.json still has the example values. '
        'Put in your Supabase Project URL and anon (publishable) key.',
      );
    }
  }

  /// Firebase for this phone's platform, or null when config/dev.json has no
  /// Firebase keys for it (or still has the example values): then there are
  /// no push notifications, and everything else works as before.
  static FirebaseOptions? get firebaseOptions {
    final (appId, apiKey) = switch (defaultTargetPlatform) {
      TargetPlatform.android => (_firebaseAndroidAppId, _firebaseAndroidApiKey),
      TargetPlatform.iOS => (_firebaseIosAppId, _firebaseIosApiKey),
      _ => ('', ''),
    };
    final values = [_firebaseProjectId, _firebaseSenderId, appId, apiKey];
    if (values.any((v) => v.isEmpty || v.startsWith('YOUR-'))) return null;
    return FirebaseOptions(
      apiKey: apiKey,
      appId: appId,
      messagingSenderId: _firebaseSenderId,
      projectId: _firebaseProjectId,
    );
  }

  /// The Google client IDs for this phone's platform, or null when
  /// config/dev.json has none for it (or still has the example values): then
  /// the log in screen has no 'Continue with Google' button. Android only
  /// needs the Web client's ID; iOS needs its own client's ID as well.
  static ({String webClientId, String? iosClientId})? get googleClientIds {
    final needed = switch (defaultTargetPlatform) {
      TargetPlatform.android => [_googleWebClientId],
      TargetPlatform.iOS => [_googleWebClientId, _googleIosClientId],
      _ => [''],
    };
    if (needed.any((v) => v.isEmpty || v.startsWith('YOUR-'))) return null;
    return (
      webClientId: _googleWebClientId,
      iosClientId: defaultTargetPlatform == TargetPlatform.iOS ? _googleIosClientId : null,
    );
  }
}
