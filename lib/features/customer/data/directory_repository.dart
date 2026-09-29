import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/supabase/supabase_client.dart';
import '../../../shared/models/service_category.dart';
import '../../../shared/models/worker_listing.dart';
import '../../../shared/models/worker_service.dart';

/// A worker found by a search, with their price note for that service (C2).
typedef WorkerResult = ({WorkerListing worker, String? priceNote});

/// Everything C3 shows about one worker, apart from reviews.
typedef WorkerDetails = ({WorkerListing worker, List<WorkerService> services});

/// The only place in this feature that talks to Supabase.
class DirectoryRepository {
  final SupabaseClient _db;
  DirectoryRepository(this._db);

  /// C1: active service_categories, in the order the admin set.
  Future<List<ServiceCategory>> getCategories() async {
    final rows = await _db
        .from('service_categories')
        .select()
        .eq('is_active', true)
        .order('sort_order', ascending: true);
    return rows.map(ServiceCategory.fromJson).toList();
  }

  /// C2: approved workers offering [categoryId] in [dzongkhag] (null: all of
  /// Bhutan). worker_directory is a view and can't embed worker_services, so
  /// this is two queries: who offers the service, then which of them are listed.
  /// [includeUnlisted] (admins) adds the workers customers don't see, after the
  /// rest: not approved yet, rejected, or deactivated.
  Future<List<WorkerResult>> searchWorkers({
    required String categoryId,
    required String? dzongkhag,
    required WorkerSort sort,
    bool includeUnlisted = false,
  }) async {
    final offers = await _db
        .from('worker_services')
        .select('worker_id, price_note')
        .eq('category_id', categoryId);
    if (offers.isEmpty) return [];
    final priceNotes = {
      for (final offer in offers) offer['worker_id'] as String: offer['price_note'] as String?,
    };

    final (first, then) = switch (sort) {
      WorkerSort.rating => ('avg_rating', 'review_count'),
      WorkerSort.reviews => ('review_count', 'avg_rating'),
      WorkerSort.experience => ('years_experience', 'avg_rating'),
    };
    var listed = _db.from('worker_directory').select().inFilter('id', priceNotes.keys.toList());
    if (dzongkhag != null) listed = listed.eq('dzongkhag', dzongkhag);
    final rows = await listed.order(first).order(then);
    final workers = rows.map(WorkerListing.fromJson).toList();

    if (includeUnlisted) {
      final listed = {for (final worker in workers) worker.id};
      final everyone = await _db
          .from('worker_profiles')
          .select(WorkerListing.workerProfileColumns)
          .inFilter('id', priceNotes.keys.toList())
          .order('created_at');
      workers.addAll(everyone
          .where(WorkerListing.isCurrentWorker)
          .map(WorkerListing.fromWorkerProfile)
          .where((worker) =>
              !listed.contains(worker.id) && (dzongkhag == null || worker.dzongkhag == dzongkhag)));
    }
    return [for (final worker in workers) (worker: worker, priceNote: priceNotes[worker.id])];
  }

  /// C3 (and B5 for the worker's own listing). Null when this user can't see
  /// the worker: customers only see approved ones.
  Future<WorkerDetails?> getWorker(String id) async {
    final (row, services) = await (
      _db.from('worker_directory').select().eq('id', id).maybeSingle(),
      _db
          .from('worker_services')
          .select('worker_id, category_id, price_note, service_categories(name, icon)')
          .eq('worker_id', id),
    ).wait;
    final worker = row != null ? WorkerListing.fromJson(row) : await _unlistedWorker(id);
    if (worker == null) return null;
    return (worker: worker, services: services.map(WorkerService.fromJson).toList());
  }

  /// A worker who isn't approved. The database rules only return the row to
  /// admins and to the worker themself; everyone else gets null.
  Future<WorkerListing?> _unlistedWorker(String id) async {
    final row = await _db
        .from('worker_profiles')
        .select(WorkerListing.workerProfileColumns)
        .eq('id', id)
        .maybeSingle();
    return row == null ? null : WorkerListing.fromWorkerProfile(row);
  }
}

final directoryRepositoryProvider = Provider<DirectoryRepository>((ref) => DirectoryRepository(ref.watch(supabaseProvider)));
