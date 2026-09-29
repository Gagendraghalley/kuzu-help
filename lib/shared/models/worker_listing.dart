import '../../core/constants/app_constants.dart';

/// Maps the one row of the worker_directory view (approved workers only), or,
/// for admins, a worker not approved yet (see [WorkerListing.fromWorkerProfile]).
class WorkerListing {
  final String id;
  final String fullName;
  final String? avatarUrl;
  final String dzongkhag;
  final String? town;
  final String? bio;
  final int yearsExperience;
  final String? whatsappNumber;
  final bool isAvailable;
  final double avgRating;
  final int reviewCount;
  final String verificationStatus;
  final bool isActive; // false once an admin deactivates the account

  const WorkerListing({
    required this.id,
    required this.fullName,
    this.avatarUrl,
    required this.dzongkhag,
    this.town,
    this.bio,
    required this.yearsExperience,
    this.whatsappNumber,
    required this.isAvailable,
    required this.avgRating,
    required this.reviewCount,
    this.verificationStatus = VerificationStatus.approved,
    this.isActive = true,
  });

  factory WorkerListing.fromJson(Map<String, dynamic> json) => WorkerListing(
        id: json['id'] as String,
        fullName: json['full_name'] as String? ?? '',
        avatarUrl: json['avatar_url'] as String?,
        dzongkhag: json['dzongkhag'] as String? ?? '',
        town: json['town'] as String?,
        bio: json['bio'] as String?,
        yearsExperience: json['years_experience'] as int? ?? 0,
        whatsappNumber: json['whatsapp_number'] as String?,
        isAvailable: json['is_available'] as bool? ?? true,
        avgRating: (json['avg_rating'] as num?)?.toDouble() ?? 0,
        reviewCount: json['review_count'] as int? ?? 0,
      );

  /// A worker_profiles row selected with [workerProfileColumns]: a worker who
  /// isn't in worker_directory because they aren't approved, or are
  /// deactivated. The database rules only return these rows to admins (and to
  /// the worker themself).
  factory WorkerListing.fromWorkerProfile(Map<String, dynamic> json) {
    final profile = json['profiles'] as Map<String, dynamic>? ?? const {};
    return WorkerListing(
      id: json['id'] as String,
      fullName: profile['full_name'] as String? ?? '',
      avatarUrl: profile['avatar_url'] as String?,
      dzongkhag: profile['dzongkhag'] as String? ?? '',
      town: profile['town'] as String?,
      bio: json['bio'] as String?,
      yearsExperience: json['years_experience'] as int? ?? 0,
      whatsappNumber: json['whatsapp_number'] as String?,
      isAvailable: json['is_available'] as bool? ?? true,
      avgRating: 0,
      reviewCount: 0,
      verificationStatus: json['verification_status'] as String? ?? VerificationStatus.pending,
      isActive: profile['is_active'] as bool? ?? true,
    );
  }

  /// profiles(*) rather than named columns, so this still works before
  /// supabase/updates.sql adds is_active.
  static const workerProfileColumns =
      'id, bio, years_experience, whatsapp_number, is_available, verification_status, profiles(*)';

  /// False for a [workerProfileColumns] row of someone who stopped offering
  /// services (supabase/updates.sql): their worker profile is kept but hidden.
  static bool isCurrentWorker(Map<String, dynamic> row) =>
      (row['profiles'] as Map<String, dynamic>?)?['role'] == UserRole.worker;

  bool get isApproved => verificationStatus == VerificationStatus.approved;

  /// 'Town, Dzongkhag', or whichever of the two is known.
  String get location =>
      [town, dzongkhag].where((part) => part != null && part.trim().isNotEmpty).join(', ');
}
