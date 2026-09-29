/// How far a worker has got through setup (B1 profile, B2 services,
/// B3 verification) and their approval status. Read from worker_profiles
/// together with its worker_services and worker_verifications rows.
class WorkerProgress {
  final bool hasProfile;
  final bool hasServices;
  final bool hasVerification;
  final String? status; // a VerificationStatus value; null before B1

  const WorkerProgress({
    required this.hasProfile,
    this.hasServices = false,
    this.hasVerification = false,
    this.status,
  });

  /// A worker who hasn't saved B1 yet (no worker_profiles row).
  static const notStarted = WorkerProgress(hasProfile: false);

  factory WorkerProgress.fromJson(Map<String, dynamic>? json) {
    if (json == null) return notStarted;
    final services = json['worker_services'];
    final verification = json['worker_verifications'];
    return WorkerProgress(
      hasProfile: true,
      hasServices: services is List && services.isNotEmpty,
      // One-to-one embeds come back as an object or null; accept a list too.
      hasVerification: verification is List ? verification.isNotEmpty : verification != null,
      status: json['verification_status'] as String?,
    );
  }
}
