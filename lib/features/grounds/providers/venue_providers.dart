import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/dzongkhags.dart';
import '../../../shared/models/ground_booking.dart';
import '../../../shared/models/venue.dart';
import '../../../shared/models/venue_review.dart';
import '../../customer/providers/search_providers.dart';
import '../data/venue_repository.dart';

// Riverpod providers: venues customers can book, one venue's page, free
// times, reviews; the venues a manager runs; every venue (admins).
// Screens watch these; these call the repositories in ../data/.

/// Sports grounds: listed venues in the dzongkhag chosen on Customer Home
/// (the same choice as for workers).
final venuesProvider = FutureProvider.autoDispose<List<Venue>>((ref) async {
  final repo = ref.watch(venueRepositoryProvider);
  final area = await ref.watch(selectedDzongkhagProvider.future);
  return repo.getVenues(dzongkhag: area == kAllDzongkhags ? null : area);
});

/// Only venues with this Sport value; null: every sport.
final sportFilterProvider = StateProvider<String?>((ref) => null);

/// A venue's page, and the screens that run it. Invalidate
/// after changing the venue or its grounds.
final venueDetailsProvider = FutureProvider.autoDispose.family<VenueDetails?, String>(
    (ref, venueId) => ref.watch(venueRepositoryProvider).getVenue(venueId));

/// The times taken on a ground on a Bhutan day.
final availabilityProvider = FutureProvider.autoDispose.family<List<BusyTime>, ({String groundId, DateTime day})>(
    (ref, key) => ref.watch(venueRepositoryProvider).getAvailability(key.groundId, key.day));

final venueReviewsProvider = FutureProvider.autoDispose.family<List<VenueReview>, String>(
    (ref, venueId) => ref.watch(venueRepositoryProvider).getReviews(venueId));

final myVenueReviewProvider = FutureProvider.autoDispose.family<VenueReview?, String>(
    (ref, venueId) => ref.watch(venueRepositoryProvider).getMyReview(venueId));

/// A venue manager's home: the venues they run. Invalidate after changing one.
final myVenuesProvider =
    FutureProvider.autoDispose<List<Venue>>((ref) => ref.watch(venueRepositoryProvider).getMyVenues());

/// Settings -> Sports venues (admins): every venue, with its manager.
/// Invalidate after adding a venue or changing its manager.
final allVenuesProvider =
    FutureProvider.autoDispose<List<Venue>>((ref) => ref.watch(venueRepositoryProvider).getAllVenues());
