import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase/supabase_client.dart';
import '../../../shared/models/worker_listing.dart';

/// The only place in this feature that talks to Supabase about saved workers
/// (supabase/updates.sql, section 10). Each customer sees only their own.
class SavedWorkersRepository {
  final SupabaseClient _db;
  SavedWorkersRepository(this._db);

  String get _userId => _db.auth.currentUser!.id;

  /// Saved workers customers can still see, most recently saved first.
  Future<List<WorkerListing>> getSavedWorkers() async {
    final saved = await _db
        .from('saved_workers')
        .select('worker_id')
        .eq('customer_id', _userId)
        .order('created_at');
    if (saved.isEmpty) return [];
    final ids = [for (final row in saved) row['worker_id'] as String];
    final rows = await _db.from('worker_directory').select().inFilter('id', ids);
    final listed = {for (final row in rows) row['id'] as String: WorkerListing.fromJson(row)};
    return [for (final id in ids) if (listed[id] case final worker?) worker];
  }

  Future<bool> isSaved(String workerId) async {
    final row = await _db
        .from('saved_workers')
        .select('worker_id')
        .eq('customer_id', _userId)
        .eq('worker_id', workerId)
        .maybeSingle();
    return row != null;
  }

  Future<void> setSaved(String workerId, {required bool saved}) async {
    if (saved) {
      await _db
          .from('saved_workers')
          .upsert({'customer_id': _userId, 'worker_id': workerId}, ignoreDuplicates: true);
    } else {
      await _db.from('saved_workers').delete().eq('customer_id', _userId).eq('worker_id', workerId);
    }
  }
}

final savedWorkersRepositoryProvider =
    Provider<SavedWorkersRepository>((ref) => SavedWorkersRepository(ref.watch(supabaseProvider)));
