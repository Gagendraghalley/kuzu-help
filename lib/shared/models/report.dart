/// Maps a report_list row (the reports table with names, supabase/updates.sql
/// section 6). Only admins get the names.
class Report {
  final String id;
  final String workerId;
  final String workerName;
  final String? workerAvatarUrl;
  final String reporterName;
  final String? reporterEmail;
  final String reason; // a ReportReasons value
  final String? details;
  final String status; // a ReportStatus value
  final DateTime createdAt;

  const Report({
    required this.id,
    required this.workerId,
    this.workerName = '',
    this.workerAvatarUrl,
    this.reporterName = '',
    this.reporterEmail,
    required this.reason,
    this.details,
    required this.status,
    required this.createdAt,
  });

  factory Report.fromJson(Map<String, dynamic> json) => Report(
        id: json['id'] as String,
        workerId: json['worker_id'] as String,
        workerName: json['worker_name'] as String? ?? '',
        workerAvatarUrl: json['worker_avatar_url'] as String?,
        reporterName: json['reporter_name'] as String? ?? '',
        reporterEmail: json['reporter_email'] as String?,
        reason: json['reason'] as String,
        details: json['details'] as String?,
        status: json['status'] as String,
        createdAt: DateTime.parse(json['created_at'] as String),
      );
}
