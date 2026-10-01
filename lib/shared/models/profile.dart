import '../../core/constants/app_constants.dart';

/// Maps the profiles table (supabase/schema.sql, plus is_active,
/// deactivated_reason and roles from supabase/updates.sql).
class Profile {
  final String id;
  final String fullName;
  final String role; // the main one: which home the app opens
  final List<String> roles; // every role the account has, one per service it uses
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
    this.roles = const [],
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
        roles: [...?(json['roles'] as List?)?.cast<String>()],
        phone: json['phone'] as String?,
        email: json['email'] as String?,
        avatarUrl: json['avatar_url'] as String?,
        dzongkhag: json['dzongkhag'] as String?,
        town: json['town'] as String?,
        // Missing before supabase/updates.sql is run: everyone is active.
        isActive: json['is_active'] as bool? ?? true,
        deactivatedReason: json['deactivated_reason'] as String?,
      );

  /// The account may use [check]'s service, as the database checks
  /// (has_role): its main role, one it added, or an admin's.
  bool hasRole(String check) => role == check || roles.contains(check) || role == UserRole.admin;

  /// Every role, the main one first.
  List<String> get allRoles => [role, ...roles.where((r) => r != role)];
}
