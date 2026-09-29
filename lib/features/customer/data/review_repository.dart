import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase/supabase_client.dart';
import '../../../shared/models/review.dart';

/// The only place in this feature that talks to Supabase.
class ReviewRepository {
  final SupabaseClient _db;
  ReviewRepository(this._db);

  /// C3 and B5: newest first.
  Future<List<Review>> getReviews(String workerId) async {
    final rows = await _db
        .from('reviews')
        .select()
        .eq('worker_id', workerId)
        .order('created_at')
        .limit(50);
    return rows.map(Review.fromJson).toList();
  }

  /// C4: the logged-in customer's review of [workerId], to edit.
  Future<Review?> getMyReview(String workerId) async {
    final row = await _db
        .from('reviews')
        .select()
        .eq('worker_id', workerId)
        .eq('customer_id', _db.auth.currentUser!.id)
        .maybeSingle();
    return row == null ? null : Review.fromJson(row);
  }

  /// C4: one review per customer per worker, so saving again replaces it.
  Future<void> saveReview({required String workerId, required int rating, String? comment}) async {
    await _db.from('reviews').upsert({
      'worker_id': workerId,
      'customer_id': _db.auth.currentUser!.id,
      'rating': rating,
      'comment': comment,
    }, onConflict: 'worker_id,customer_id');
  }
}

final reviewRepositoryProvider = Provider<ReviewRepository>((ref) => ReviewRepository(ref.watch(supabaseProvider)));
