/// Maps the profiles table (supabase/schema.sql, plus is_active and
/// deactivated_reason from supabase/updates.sql).
class Profile {
  final String id;
  final String fullName;
  final String role;
  final String? phone;
  final String? email;
  final String? avatarUrl;
  final String? dzongkhag;
  final String? town;
  final bool isActive; // false once an admin deactivates the account
  final String? deactivatedReason;

  const Profile({
    required this.id,
    required this.fullName,
    required this.role,
    this.phone,
    this.email,
    this.avatarUrl,
    this.dzongkhag,
    this.town,
    this.isActive = true,
    this.deactivatedReason,
  });

  factory Profile.fromJson(Map<String, dynamic> json) => Profile(
        id: json['id'] as String,
        fullName: json['full_name'] as String? ?? '',
        role: json['role'] as String,
        phone: json['phone'] as String?,
        email: json['email'] as String?,
        avatarUrl: json['avatar_url'] as String?,
        dzongkhag: json['dzongkhag'] as String?,
        town: json['town'] as String?,
        // Missing before supabase/updates.sql is run: everyone is active.
        isActive: json['is_active'] as bool? ?? true,
        deactivatedReason: json['deactivated_reason'] as String?,
      );
}
