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

  AppNotification markedRead(DateTime at) =>
      AppNotification(id: id, type: type, data: data, createdAt: createdAt, readAt: readAt ?? at);

  factory AppNotification.fromJson(Map<String, dynamic> json) => AppNotification(
        id: json['id'] as String,
        type: json['type'] as String,
        data: (json['data'] as Map?)?.cast<String, dynamic>() ?? const {},
        createdAt: DateTime.parse(json['created_at'] as String),
        readAt: json['read_at'] == null ? null : DateTime.parse(json['read_at'] as String),
      );
}
