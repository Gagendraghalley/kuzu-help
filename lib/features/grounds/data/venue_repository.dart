import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/supabase/supabase_client.dart';
import '../../../core/utils/bhutan_time.dart';
import '../../../core/utils/storage_paths.dart';
import '../../../shared/models/ground.dart';
import '../../../shared/models/ground_booking.dart';
import '../../../shared/models/venue.dart';
import '../../../shared/models/venue_review.dart';

/// Everything a venue's page shows, apart from reviews.
typedef VenueDetails = ({Venue venue, List<Ground> grounds});

/// The account of a venue's manager, from the create-venue-manager Edge
/// Function. [created] is false when the email already had an account.
typedef ManagerAccount = ({String userId, bool created});

/// Talks to Supabase about venues, grounds and venue reviews
/// (supabase/updates.sql, section 13): what customers see, what a venue's
/// manager runs, and what admins set up. Bookings are in booking_repository.dart.
class VenueRepository {
  final SupabaseClient _db;
  VenueRepository(this._db);

  String get _userId => _db.auth.currentUser!.id;

  // Customers

  /// Listed sports venues in [dzongkhag] (null: all of Bhutan), best rated first.
  Future<List<Venue>> getVenues({String? dzongkhag}) async {
    var query = _db.from('venue_directory').select().eq('venue_type', VenueType.sportsGround);
    if (dzongkhag != null) query = query.eq('dzongkhag', dzongkhag);
    final rows = await query.order('avg_rating').order('review_count').limit(100);
    return rows.map(Venue.fromJson).toList();
  }

  /// A venue's page, with all its grounds. Customers, and visitors who
  /// haven't logged in, see listed venues; the manager sees theirs and admins
  /// any, with its manager and, when it's listed, its rating. Null when this
  /// user can't see it.
  Future<VenueDetails?> getVenue(String id) async {
    // The manager and admins only; visitors may not read venues at all.
    final Future<Map<String, dynamic>?> managedRow = _db.auth.currentUser == null
        ? Future.value(null)
        : _db.from('venues').select(Venue.columns).eq('id', id).maybeSingle();
    final (listed, managed, grounds) = await (
      _db.from('venue_directory').select().eq('id', id).maybeSingle(),
      managedRow,
      _db.from('grounds').select(Ground.columns).eq('venue_id', id).order('created_at', ascending: true),
    ).wait;
    if (listed == null && managed == null) return null;
    return (venue: Venue.fromJson({...?listed, ...?managed}), grounds: grounds.map(Ground.fromJson).toList());
  }

  /// The times already taken on [day] (Bhutan time), for choosing a free one.
  Future<List<BusyTime>> getAvailability(String groundId, DateTime day) async {
    final rows = await _db.rpc('get_ground_availability', params: {
      'ground': groundId,
      'day': BhutanTime.isoDate(day),
    }) as List;
    return [
      for (final row in rows.cast<Map<String, dynamic>>())
        (
          start: DateTime.parse(row['start_time'] as String),
          end: DateTime.parse(row['end_time'] as String),
          blocked: row['blocked'] as bool? ?? false,
          confirmed: row['confirmed'] as bool? ?? true,
          regular: row['regular'] as bool? ?? false,
        ),
    ];
  }

  Future<List<VenueReview>> getReviews(String venueId) async {
    final rows = await _db
        .from('venue_reviews')
        .select()
        .eq('venue_id', venueId)
        .order('created_at')
        .limit(100);
    return rows.map(VenueReview.fromJson).toList();
  }

  Future<VenueReview?> getMyReview(String venueId) async {
    final row = await _db
        .from('venue_reviews')
        .select()
        .eq('venue_id', venueId)
        .eq('customer_id', _userId)
        .maybeSingle();
    return row == null ? null : VenueReview.fromJson(row);
  }

  /// One review per customer per venue; saving again changes it. The
  /// database only takes it from customers who have played there.
  Future<void> saveReview({required String venueId, required int rating, String? comment}) async {
    await _db.from('venue_reviews').upsert({
      'venue_id': venueId,
      'customer_id': _userId,
      'rating': rating,
      'comment': comment,
    }, onConflict: 'venue_id,customer_id');
  }

  // Venue managers (admins can do all of this too)

  /// The venues this user manages, oldest first.
  Future<List<Venue>> getMyVenues() async {
    final rows = await _db
        .from('venues')
        .select(Venue.columns)
        .eq('manager_id', _userId)
        .order('created_at', ascending: true);
    return rows.map(Venue.fromJson).toList();
  }

  /// A null [cover] keeps the photo it has.
  Future<void> updateVenue(String venueId, VenueDraft draft, {Uint8List? cover}) async {
    await _db.from('venues').update({
      ...draft.toJson(),
      if (cover != null) 'cover_url': await _uploadCover(cover),
    }).eq('id', venueId);
  }

  /// Pause bookings (customers stop seeing the venue), or take them again.
  Future<void> setVenueActive(String venueId, bool active) async {
    await _db.from('venues').update({'is_active': active}).eq('id', venueId);
  }

  /// Saves the ground's type and price: adds it the first time, changes it after.
  Future<void> saveGround(String venueId, GroundDraft draft) async {
    final id = draft.id;
    if (id == null) {
      await _db.from('grounds').insert({...draft.toJson(), 'venue_id': venueId});
    } else {
      await _db.from('grounds').update(draft.toJson()).eq('id', id);
    }
  }

  /// The ground's timings for the whole week, replacing the ones it had
  /// (set_ground_time_slots). No slot on a day: closed that day.
  Future<void> saveTimeSlots(String groundId, List<TimeSlot> slots) async {
    await _db.rpc('set_ground_time_slots', params: {
      'ground': groundId,
      'slots': [for (final s in slots.toSet()) s.toJson()],
    });
  }

  // Admins

  /// Every venue, with its manager, by name.
  Future<List<Venue>> getAllVenues() async {
    final rows = await _db.from('venues').select(Venue.columns).order('name', ascending: true);
    return rows.map(Venue.fromJson).toList();
  }

  /// Registers a venue together with its manager ([managerId], from
  /// [createManagerAccount]) and its [ground]'s type and price, all or
  /// nothing (add_venue). Postgres error 22023: that account can't run a
  /// venue. Returns the venue's ID.
  Future<String> addVenue(VenueDraft draft, {required String managerId, required GroundDraft ground, Uint8List? cover}) async {
    final id = await _db.rpc('add_venue', params: {
      'details': {
        ...draft.toJson(),
        'venue_type': VenueType.sportsGround,
        if (cover != null) 'cover_url': await _uploadCover(cover),
        'ground': ground.toJson(),
      },
      'manager': managerId,
    });
    return id as String;
  }

  /// Makes a Kuzu Help account for [email], or finds the one it has (the
  /// create-venue-manager Edge Function: only it may make accounts). [phone]
  /// is +975XXXXXXXX.
  Future<ManagerAccount> createManagerAccount({
    required String email,
    required String fullName,
    String? phone,
  }) async {
    final response = await _db.functions.invoke('create-venue-manager', body: {
      'email': email,
      'full_name': fullName,
      'phone': phone,
    });
    final data = response.data as Map<String, dynamic>;
    return (userId: data['user_id'] as String, created: data['created'] as bool? ?? false);
  }

  /// Gives the venue its manager, or none ([managerId] null). The database
  /// refuses admins', workers' and deactivated accounts (Postgres error 22023).
  Future<void> setVenueManager(String venueId, String? managerId) async {
    await _db.rpc('set_venue_manager', params: {'venue': venueId, 'manager': managerId});
  }

  /// A new file name each time, so phones that cached the old photo show the new one.
  Future<String> _uploadCover(Uint8List cover) async {
    final path = StoragePaths.venueCover(_userId);
    final bucket = _db.storage.from(Buckets.venuePhotos);
    await bucket.uploadBinary(path, cover, fileOptions: const FileOptions(contentType: 'image/jpeg'));
    return bucket.getPublicUrl(path);
  }
}

final venueRepositoryProvider = Provider<VenueRepository>((ref) => VenueRepository(ref.watch(supabaseProvider)));
