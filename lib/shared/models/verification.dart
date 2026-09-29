/// Maps the worker_verifications table.
class Verification {
  final String workerId;
  final String cidPath;
  final String? certificatePath;
  final DateTime submittedAt;

  const Verification({
    required this.workerId,
    required this.cidPath,
    this.certificatePath,
    required this.submittedAt,
  });

  factory Verification.fromJson(Map<String, dynamic> json) => Verification(
        workerId: json['worker_id'] as String,
        cidPath: json['cid_path'] as String,
        certificatePath: json['certificate_path'] as String?,
        submittedAt: DateTime.parse(json['submitted_at'] as String),
      );
}
