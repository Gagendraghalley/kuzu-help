/// Maps the reports table.
class Report {
  final String id;
  final String workerId;
  final String reason;
  final String? details;
  final String status;

  const Report({
    required this.id,
    required this.workerId,
    required this.reason,
    this.details,
    required this.status,
  });

  factory Report.fromJson(Map<String, dynamic> json) => Report(
        id: json['id'] as String,
        workerId: json['worker_id'] as String,
        reason: json['reason'] as String,
        details: json['details'] as String?,
        status: json['status'] as String,
      );
}
