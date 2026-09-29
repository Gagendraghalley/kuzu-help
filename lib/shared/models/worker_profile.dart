import '../../core/constants/app_constants.dart';

/// Maps the worker's own worker_profiles row.
/// There is no toJson: workers may only write some columns (schema.sql,
/// section 5), so the repository sends just those.
class WorkerProfile {
  final String id;
  final String? bio;
  final int yearsExperience;
  final String? whatsappNumber;
  final bool isAvailable;
  final String verificationStatus;
  final String? adminNotes;

  const WorkerProfile({
    required this.id,
    this.bio,
    required this.yearsExperience,
    this.whatsappNumber,
    required this.isAvailable,
    required this.verificationStatus,
    this.adminNotes,
  });

  factory WorkerProfile.fromJson(Map<String, dynamic> json) => WorkerProfile(
        id: json['id'] as String,
        bio: json['bio'] as String?,
        yearsExperience: json['years_experience'] as int? ?? 0,
        whatsappNumber: json['whatsapp_number'] as String?,
        isAvailable: json['is_available'] as bool? ?? true,
        verificationStatus: json['verification_status'] as String? ?? VerificationStatus.pending,
        adminNotes: json['admin_notes'] as String?,
      );
}
