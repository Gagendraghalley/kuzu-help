import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase/supabase_client.dart';

/// The only place in this feature that talks to Supabase.
class ReportRepository {
  final SupabaseClient _db;
  ReportRepository(this._db);

  /// C5: [reason] is one of ReportReasons.all. The database sets status to
  /// 'open'; only admins change it.
  Future<void> submitReport({required String workerId, required String reason, String? details}) async {
    await _db.from('reports').insert({
      'worker_id': workerId,
      'reporter_id': _db.auth.currentUser!.id,
      'reason': reason,
      'details': details,
    });
  }
}

final reportRepositoryProvider = Provider<ReportRepository>((ref) => ReportRepository(ref.watch(supabaseProvider)));
