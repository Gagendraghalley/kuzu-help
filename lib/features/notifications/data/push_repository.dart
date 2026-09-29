import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/config/env.dart';
import '../../../core/supabase/supabase_client.dart';

/// Push notifications through Firebase Cloud Messaging (Android, and iPhones
/// through Apple's push service): each notification in the bell also reaches
/// the phone when the app is closed. The database sends
/// them (supabase/updates.sql section 12, and the send-push Edge Function);
/// this keeps each phone's token and opens the ones tapped.
/// Does nothing when config/dev.json has no Firebase keys for this platform,
/// and never stops the app working: problems are only logged.
class PushRepository {
  final SupabaseClient _db;
  PushRepository(this._db);

  static bool _enabled = false;
  StreamSubscription<String>? _tokenChanges;

  /// Called once from main(), before the app starts.
  static Future<void> initialize() async {
    final options = Env.firebaseOptions;
    if (options == null) return;
    try {
      await Firebase.initializeApp(options: options);
      _enabled = true;
    } catch (e) {
      debugPrint('Push notifications are off: $e');
    }
  }

  /// Asks to show notifications (Android 13+ and iPhones show a prompt), then
  /// saves this phone's token for the logged-in user, and again whenever it
  /// changes.
  Future<void> register() async {
    if (!_enabled) return;
    try {
      final messaging = FirebaseMessaging.instance;
      final settings = await messaging.requestPermission();
      if (settings.authorizationStatus == AuthorizationStatus.denied) return;
      // Listening first, so a token that only comes later is saved too.
      _tokenChanges ??= messaging.onTokenRefresh.listen((token) => _save(token).catchError(_log));
      // iPhones: Firebase needs Apple's push token first, which can take a moment.
      if (defaultTargetPlatform == TargetPlatform.iOS) {
        for (var i = 0; i < 10 && await messaging.getAPNSToken() == null; i++) {
          await Future<void>.delayed(const Duration(milliseconds: 500));
        }
      }
      final token = await messaging.getToken();
      if (token != null) await _save(token);
    } catch (e) {
      _log(e);
    }
  }

  /// Before logging out: this phone stops getting the user's notifications.
  /// Gives up after a few seconds, so logging out works offline.
  Future<void> unregister() async {
    if (!_enabled) return;
    try {
      final token = await FirebaseMessaging.instance.getToken().timeout(const Duration(seconds: 3));
      if (token == null) return;
      await _db
          .rpc('unregister_push_token', params: {'push_token': token})
          .timeout(const Duration(seconds: 3));
    } catch (e) {
      // The next user to log in on this phone takes the token over anyway.
      _log(e);
    }
  }

  /// The data of each push notification the user taps: first the one that
  /// opened the app, if any, then any tapped while it's running.
  Stream<Map<String, dynamic>> get openedNotifications async* {
    if (!_enabled) return;
    final initial = await FirebaseMessaging.instance.getInitialMessage();
    if (initial != null) yield initial.data;
    yield* FirebaseMessaging.onMessageOpenedApp.map((message) => message.data);
  }

  Future<void> _save(String token) => _db.rpc('register_push_token', params: {
        'push_token': token,
        'device_platform': defaultTargetPlatform == TargetPlatform.iOS ? 'ios' : 'android',
      });

  static void _log(Object e) => debugPrint('Push notifications: $e');
}

final pushRepositoryProvider = Provider<PushRepository>((ref) => PushRepository(ref.watch(supabaseProvider)));

/// Registers this phone for the logged-in user's push notifications. Home
/// screens watch it (through the bell); logging out resets it.
final pushRegistrationProvider = FutureProvider<void>((ref) => ref.watch(pushRepositoryProvider).register());
