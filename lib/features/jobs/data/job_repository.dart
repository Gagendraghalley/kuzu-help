import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/supabase/supabase_client.dart';
import '../../../core/utils/storage_paths.dart';
import '../../../shared/models/job_request.dart';

/// The only place in this feature that talks to Supabase (job_requests,
/// supabase/updates.sql section 11).
class JobRepository {
  final SupabaseClient _db;
  JobRepository(this._db);

  static const _linkSeconds = 10 * 60;

  String get _userId => _db.auth.currentUser!.id;

  /// Workers: the requests sent to them. Everyone else: the ones they sent.
  /// Newest first.
  Future<List<JobRequest>> getMyJobs({required bool asWorker}) async {
    final rows = await _db
        .from('job_requests')
        .select(JobRequest.columns)
        .eq(asWorker ? 'worker_id' : 'customer_id', _userId)
        .order('created_at')
        .limit(100);
    return rows.map(JobRequest.fromJson).toList();
  }

  /// [contactPhone] is +975XXXXXXXX; [photo] a compressed JPEG. The database
  /// refuses a second open request to the same worker (Postgres code 23505),
  /// and requests to workers who aren't taking work.
  Future<void> sendRequest({
    required String workerId,
    String? categoryId,
    required String description,
    String? whenNeeded,
    required String address,
    required String contactPhone,
    Uint8List? photo,
  }) async {
    String? photoPath;
    if (photo != null) {
      photoPath = StoragePaths.jobPhoto(_userId);
      await _db.storage
          .from(Buckets.jobPhotos)
          .uploadBinary(photoPath, photo, fileOptions: const FileOptions(contentType: 'image/jpeg'));
    }
    await _db.from('job_requests').insert({
      'customer_id': _userId,
      'worker_id': workerId,
      'category_id': categoryId,
      'description': description,
      'when_needed': whenNeeded,
      'address': address,
      'contact_phone': contactPhone,
      'photo_path': photoPath,
    });
  }

  /// A JobStatus value; the database checks who may make each change.
  /// [note] goes with accepting or declining.
  Future<void> setStatus(String requestId, String status, {String? note}) async {
    await _db.rpc('set_job_status', params: {'request_id': requestId, 'new_status': status, 'note': note});
  }

  /// A link to the job's photo that expires soon.
  Future<String> photoUrl(String path) =>
      _db.storage.from(Buckets.jobPhotos).createSignedUrl(path, _linkSeconds);
}

final jobRepositoryProvider = Provider<JobRepository>((ref) => JobRepository(ref.watch(supabaseProvider)));
