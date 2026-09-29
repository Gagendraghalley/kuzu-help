import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase/supabase_client.dart';
import '../../../shared/models/app_notification.dart';

/// The only place in this feature that talks to Supabase. The database adds
/// the notifications itself (supabase/updates.sql, section 5).
class NotificationRepository {
  final SupabaseClient _db;
  NotificationRepository(this._db);

  static const _shown = 50;

  String get _userId => _db.auth.currentUser!.id;

  /// The logged-in user's newest notifications, newest first. Supabase
  /// Realtime sends a new list whenever one arrives or is marked read.
  Stream<List<AppNotification>> watchMine() => _db
      .from('notifications')
      .stream(primaryKey: ['id'])
      .eq('user_id', _userId)
      .order('created_at')
      .limit(_shown)
      .map((rows) => rows.map(AppNotification.fromJson).toList());

  Future<void> markRead(String id) async {
    await _db
        .from('notifications')
        .update({'read_at': DateTime.now().toUtc().toIso8601String()})
        .eq('id', id)
        .isFilter('read_at', null);
  }

  Future<void> markAllRead() async {
    await _db
        .from('notifications')
        .update({'read_at': DateTime.now().toUtc().toIso8601String()})
        .eq('user_id', _userId)
        .isFilter('read_at', null);
  }

  /// C3: tells the worker a customer tapped Call or WhatsApp (a
  /// ContactMethod value). The database skips repeats within a day.
  Future<void> notifyContact(String workerId, String method) async {
    await _db.rpc('record_contact', params: {'worker_id': workerId, 'method': method});
  }
}

final notificationRepositoryProvider =
    Provider<NotificationRepository>((ref) => NotificationRepository(ref.watch(supabaseProvider)));
