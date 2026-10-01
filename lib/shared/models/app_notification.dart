import 'dart:convert';

/// Maps the notifications table (supabase/updates.sql, section 5). What it
/// says comes from [type] and [data]: see AppStrings.notificationTitle.
class AppNotification {
  final String id;
  final String type; // a NotificationTypes value
  final Map<String, dynamic> data;
  final DateTime createdAt;
  final DateTime? readAt;

  const AppNotification({
    required this.id,
    required this.type,
    this.data = const {},
    required this.createdAt,
    this.readAt,
  });

  bool get isRead => readAt != null;

  /// The worker it's about, for opening their page.
  String? get workerId => data['worker_id'] as String?;

  /// The venue it's about (sports grounds), for opening it.
  String? get venueId => data['venue_id'] as String?;

  AppNotification markedRead(DateTime at) =>
      AppNotification(id: id, type: type, data: data, createdAt: createdAt, readAt: readAt ?? at);

  /// A tapped push notification's data (supabase/functions/send-push): the
  /// notification's id and type, and its data as JSON in 'payload'. Null if
  /// it isn't one of ours.
  static AppNotification? fromPush(Map<String, dynamic> push) {
    final id = push['notification_id'];
    final type = push['type'];
    if (id is! String || type is! String) return null;
    var data = const <String, dynamic>{};
    try {
      data = (jsonDecode(push['payload'] as String? ?? '{}') as Map).cast<String, dynamic>();
    } catch (_) {
      // Opens the right screen type anyway, just without the details.
    }
    return AppNotification(id: id, type: type, data: data, createdAt: DateTime.now());
  }

  factory AppNotification.fromJson(Map<String, dynamic> json) => AppNotification(
        id: json['id'] as String,
        type: json['type'] as String,
        data: (json['data'] as Map?)?.cast<String, dynamic>() ?? const {},
        createdAt: DateTime.parse(json['created_at'] as String),
        readAt: json['read_at'] == null ? null : DateTime.parse(json['read_at'] as String),
      );
}
