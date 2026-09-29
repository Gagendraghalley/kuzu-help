import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/supabase/supabase_client.dart';
import '../../../core/utils/storage_paths.dart';
import '../../../shared/models/verification.dart';
import '../../../shared/models/worker_profile.dart';
import '../../../shared/models/worker_progress.dart';
import '../../../shared/models/worker_service.dart';

/// The only place in this feature that talks to Supabase.
class WorkerRepository {
  final SupabaseClient _db;
  WorkerRepository(this._db);

  String get _userId => _db.auth.currentUser!.id;

  /// How far the logged-in worker has got through setup; the splash (A1)
  /// uses it to open the right screen.
  Future<WorkerProgress> getMyProgress() async {
    final row = await _db
        .from('worker_profiles')
        .select('verification_status, worker_services(category_id), worker_verifications(worker_id)')
        .eq('id', _userId)
        .maybeSingle();
    return WorkerProgress.fromJson(row);
  }

  /// B1, B4: the worker's own row, with status and admin notes. Null before B1.
  Future<WorkerProfile?> getMyWorkerProfile() async {
    final row = await _db.from('worker_profiles').select().eq('id', _userId).maybeSingle();
    return row == null ? null : WorkerProfile.fromJson(row);
  }

  /// B1: the first save creates the row, with verification_status 'pending'.
  /// Name, photo and location are saved with ProfileRepository.updateProfile.
  Future<void> saveWorkerDetails({
    required String whatsappNumber,
    required int yearsExperience,
    String? bio,
  }) async {
    await _db.from('worker_profiles').upsert({
      'id': _userId,
      'whatsapp_number': whatsappNumber,
      'years_experience': yearsExperience,
      'bio': bio,
    });
  }

  /// B2: the worker's services, with each category's name and icon.
  Future<List<WorkerService>> getMyServices() async {
    final rows = await _db
        .from('worker_services')
        .select('worker_id, category_id, price_note, service_categories(name, icon)')
        .eq('worker_id', _userId);
    return rows.map(WorkerService.fromJson).toList();
  }

  /// B2: [priceNotes] maps each chosen category ID to its price note (or
  /// null). Services left out are removed. Needs at least one.
  Future<void> saveServices(Map<String, String?> priceNotes) async {
    if (priceNotes.isEmpty) throw ArgumentError('Choose at least one service');
    await _db
        .from('worker_services')
        .delete()
        .eq('worker_id', _userId)
        .not('category_id', 'in', priceNotes.keys.toList());
    await _db.from('worker_services').upsert([
      for (final entry in priceNotes.entries)
        {'worker_id': _userId, 'category_id': entry.key, 'price_note': entry.value},
    ]);
  }

  /// B3: the documents already sent, if any.
  Future<Verification?> getMyVerification() async {
    final row =
        await _db.from('worker_verifications').select().eq('worker_id', _userId).maybeSingle();
    return row == null ? null : Verification.fromJson(row);
  }

  /// B3: uploads to the private verification-docs bucket and records the
  /// paths. A null [cid] or [certificate] keeps the file already sent. The
  /// screen only calls this after the worker has ticked the consent box.
  Future<void> submitVerification({Uint8List? cid, Uint8List? certificate}) async {
    final existing = await getMyVerification();
    final bucket = _db.storage.from(Buckets.verificationDocs);
    const jpeg = FileOptions(contentType: 'image/jpeg', upsert: true);

    var cidPath = existing?.cidPath;
    if (cid != null) {
      cidPath = StoragePaths.cid(_userId);
      await bucket.uploadBinary(cidPath, cid, fileOptions: jpeg);
    }
    var certificatePath = existing?.certificatePath;
    if (certificate != null) {
      certificatePath = StoragePaths.certificate(_userId);
      await bucket.uploadBinary(certificatePath, certificate, fileOptions: jpeg);
    }
    if (cidPath == null) throw ArgumentError('A CID photo is required');

    await _db.from('worker_verifications').upsert({
      'worker_id': _userId,
      'cid_path': cidPath,
      'certificate_path': certificatePath,
      'consent_given': true,
      'submitted_at': DateTime.now().toUtc().toIso8601String(),
    });
  }

  /// B5: customers see 'Not available' when this is off.
  Future<void> setAvailability(bool available) async {
    await _db.from('worker_profiles').update({'is_available': available}).eq('id', _userId);
  }

  /// B4: a rejected worker who has fixed their details asks to be checked again.
  Future<void> requestReview() async {
    await _db.rpc('request_review');
  }
}

final workerRepositoryProvider = Provider<WorkerRepository>((ref) => WorkerRepository(ref.watch(supabaseProvider)));
