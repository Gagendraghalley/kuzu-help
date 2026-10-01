import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/supabase/supabase_client.dart';
import '../../../shared/models/profile.dart';
import '../../../shared/models/report.dart';
import '../../../shared/models/worker_listing.dart';

/// A worker's CID photo and certificate (B3), as links that expire soon.
typedef WorkerDocuments = ({String cidUrl, String? certificateUrl});

/// The only place in this feature that talks to Supabase. Admins only: the
/// database rules give everyone else nothing back, or refuse.
class AdminRepository {
  final SupabaseClient _db;
  AdminRepository(this._db);

  static const _linkSeconds = 10 * 60;

  /// Workers waiting for approval, longest waiting first.
  Future<List<WorkerListing>> getPendingWorkers() async {
    final rows = await _db
        .from('worker_profiles')
        .select(WorkerListing.workerProfileColumns)
        .eq('verification_status', VerificationStatus.pending)
        .order('created_at', ascending: true);
    return rows.where(WorkerListing.isCurrentWorker).map(WorkerListing.fromWorkerProfile).toList();
  }

  /// Links to the worker's documents in the private bucket, or null when they
  /// haven't sent any yet.
  Future<WorkerDocuments?> getDocuments(String workerId) async {
    final row = await _db
        .from('worker_verifications')
        .select('cid_path, certificate_path')
        .eq('worker_id', workerId)
        .maybeSingle();
    if (row == null) return null;
    final bucket = _db.storage.from(Buckets.verificationDocs);
    final certificatePath = row['certificate_path'] as String?;
    return (
      cidUrl: await bucket.createSignedUrl(row['cid_path'] as String, _linkSeconds),
      certificateUrl:
          certificatePath == null ? null : await bucket.createSignedUrl(certificatePath, _linkSeconds),
    );
  }

  /// A VerificationStatus value. A rejection's [note] is shown to the worker
  /// on B4. Needs supabase/updates.sql.
  Future<void> setVerification(String workerId, String status, {String? note}) async {
    await _db.rpc('set_worker_verification', params: {
      'worker_id': workerId,
      'new_status': status,
      'note': note,
    });
  }

  /// Users, newest first, whose name or email contains [search].
  Future<List<Profile>> getUsers({String search = ''}) async {
    // Characters with a meaning in PostgREST's or() filter can't be searched for.
    final term = search.replaceAll(RegExp(r'[,()*%\\]'), ' ').trim();
    var query = _db.from('profiles').select();
    if (term.isNotEmpty) query = query.or('full_name.ilike.*$term*,email.ilike.*$term*');
    final rows = await query.order('created_at').limit(100);
    return rows.map(Profile.fromJson).toList();
  }

  /// Deactivate (blacklist) or reactivate a user; [reason] is shown to them.
  /// Admins can't be deactivated. Needs supabase/updates.sql.
  Future<void> setUserActive(String userId, {required bool active, String? reason}) async {
    await _db.rpc('set_user_active', params: {
      'user_id': userId,
      'active': active,
      'reason': reason,
    });
  }

  /// Gives a user exactly [roles] (UserRole.editable, plus groundManager kept
  /// as it is); the main role follows (UserRole.mainOf). Admins' roles can't
  /// be changed. Needs supabase/updates.sql (set_user_roles).
  Future<void> setUserRoles(String userId, Set<String> roles) async {
    await _db.rpc('set_user_roles', params: {'target': userId, 'new_roles': roles.toList()});
  }

  /// Deletes a user's account for good, as 'Delete account' in their own
  /// Settings does: the delete-account Edge Function removes their files,
  /// then the account and everything linked to it. Admins' accounts can't be.
  /// A FunctionException 403 means the deployed function is older than this.
  Future<void> deleteUser(String userId) async {
    await _db.functions.invoke('delete-account', body: {'user_id': userId});
  }

  /// Reports with [status] (a ReportStatus value), newest first. Needs
  /// supabase/updates.sql.
  Future<List<Report>> getReports({required String status}) async {
    final rows = await _db
        .from('report_list')
        .select()
        .eq('status', status)
        .order('created_at')
        .limit(100);
    return rows.map(Report.fromJson).toList();
  }

  /// The customer who sent the report is told. Needs supabase/updates.sql.
  Future<void> setReportStatus(String reportId, String status) async {
    await _db.rpc('set_report_status', params: {'report_id': reportId, 'new_status': status});
  }
}

final adminRepositoryProvider = Provider<AdminRepository>((ref) => AdminRepository(ref.watch(supabaseProvider)));
