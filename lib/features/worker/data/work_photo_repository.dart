import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/supabase/supabase_client.dart';
import '../../../core/utils/storage_paths.dart';
import '../../../shared/models/work_photo.dart';

/// The only place that talks to Supabase about photos of workers' past work
/// (supabase/updates.sql, section 9). Everyone can see them; only the worker
/// adds or removes their own, up to AppConstants.maxWorkPhotos.
class WorkPhotoRepository {
  final SupabaseClient _db;
  WorkPhotoRepository(this._db);

  StorageFileApi get _bucket => _db.storage.from(Buckets.workPhotos);

  /// C3 and the worker's own photos screen, newest first.
  Future<List<WorkPhoto>> getPhotos(String workerId) async {
    final rows = await _db.from('work_photos').select().eq('worker_id', workerId).order('created_at');
    return [for (final row in rows) WorkPhoto.fromJson(row, url: _bucket.getPublicUrl(row['path'] as String))];
  }

  /// [photo] is a compressed JPEG. If the database refuses it (e.g. there are
  /// already 12), the uploaded file is removed again.
  Future<void> addPhoto(Uint8List photo) async {
    final userId = _db.auth.currentUser!.id;
    final path = StoragePaths.workPhoto(userId);
    await _bucket.uploadBinary(path, photo, fileOptions: const FileOptions(contentType: 'image/jpeg'));
    try {
      await _db.from('work_photos').insert({'worker_id': userId, 'path': path});
    } catch (_) {
      await _bucket.remove([path]);
      rethrow;
    }
  }

  Future<void> deletePhoto(WorkPhoto photo) async {
    await _db.from('work_photos').delete().eq('id', photo.id);
    await _bucket.remove([photo.path]);
  }
}

final workPhotoRepositoryProvider =
    Provider<WorkPhotoRepository>((ref) => WorkPhotoRepository(ref.watch(supabaseProvider)));
