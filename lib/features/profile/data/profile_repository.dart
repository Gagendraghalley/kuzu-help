import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/supabase/supabase_client.dart';
import '../../../core/utils/storage_paths.dart';
import '../../../shared/models/profile.dart';

/// The only place in this feature that talks to Supabase.
class ProfileRepository {
  final SupabaseClient _db;
  ProfileRepository(this._db);

  /// The logged-in user's profiles row, or null if there is none.
  Future<Profile?> getMyProfile() async {
    final userId = _db.auth.currentUser?.id;
    if (userId == null) return null;
    final row = await _db.from('profiles').select().eq('id', userId).maybeSingle();
    return row == null ? null : Profile.fromJson(row);
  }

  /// Makes the logged-in user's profiles row if their account has none, as
  /// signing up would have (ensure_my_profile); nothing when it's there.
  Future<void> ensureMyProfile() async {
    await _db.rpc('ensure_my_profile');
  }

  /// D1 and B1: name, photo and location, the only columns users may change.
  /// [photo] is a new JPEG, when one was picked.
  Future<void> updateProfile({
    required String fullName,
    String? dzongkhag,
    String? town,
    Uint8List? photo,
  }) async {
    final userId = _db.auth.currentUser!.id;
    final changes = <String, dynamic>{
      'full_name': fullName,
      'dzongkhag': dzongkhag,
      'town': town,
    };
    if (photo != null) changes['avatar_url'] = await _uploadAvatar(userId, photo);
    await _db.from('profiles').update(changes).eq('id', userId);
  }

  /// A new file name each time (storage_paths.dart), so phones that cached the
  /// old photo show the new one.
  Future<String> _uploadAvatar(String userId, Uint8List photo) async {
    final path = StoragePaths.avatar(userId);
    final bucket = _db.storage.from(Buckets.avatars);
    await bucket.uploadBinary(path, photo, fileOptions: const FileOptions(contentType: 'image/jpeg'));
    return bucket.getPublicUrl(path);
  }

  /// Uses another service with this account: [role] is UserRole.player
  /// (sports grounds) or UserRole.customer (home services), added to the
  /// ones it has (add_my_role). A player who adds home services has Customer
  /// Home from then on.
  Future<void> addRole(String role) async {
    await _db.rpc('add_my_role', params: {'new_role': role});
  }

  /// Just signed up with Google: the new account, made a customer, becomes
  /// [role] (UserRole.worker or UserRole.player) as picked on Welcome
  /// (claim_signup_role). Does nothing for an account that isn't new.
  Future<void> claimSignUpRole(String role) async {
    await _db.rpc('claim_signup_role', params: {'new_role': role});
  }

  /// B1 'I only want to find workers', for someone who signed up as a worker
  /// by mistake: worker -> customer only (supabase/updates.sql). The worker
  /// profile is kept, hidden from customers. Admins can't switch either way.
  Future<void> becomeCustomer() async {
    await _db.rpc('become_customer');
  }

  /// D1 'Delete account': the delete-account Edge Function removes the user's
  /// photos and documents, then the account; the database deletes everything
  /// linked to it. Refused for admins and deactivated users. Log out after.
  Future<void> deleteAccount() async {
    await _db.functions.invoke('delete-account');
  }
}

final profileRepositoryProvider = Provider<ProfileRepository>((ref) => ProfileRepository(ref.watch(supabaseProvider)));
