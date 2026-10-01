import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_constants.dart';
import '../../../shared/models/ground_booking.dart';
import '../../../shared/models/regular_booking.dart';
import '../../auth/data/auth_repository.dart';
import '../data/booking_repository.dart';
import 'venue_providers.dart';

// Riverpod providers: the customer's bookings, and a venue's bookings for
// whoever runs it. Screens watch these; these call the repositories in ../data/.

/// My bookings. Invalidate after booking or changing one. Visitors who
/// haven't logged in have none.
final myBookingsProvider = FutureProvider.autoDispose<List<GroundBooking>>((ref) async {
  if (!ref.watch(authRepositoryProvider).isLoggedIn) return const [];
  return ref.watch(bookingRepositoryProvider).getMyBookings();
});

/// A venue's bookings and blocked time, for its manager and admins.
final venueBookingsProvider = FutureProvider.autoDispose.family<List<GroundBooking>, String>(
    (ref, venueId) => ref.watch(bookingRepositoryProvider).getVenueBookings(venueId));

/// Requests at a venue waiting for the manager's answer.
final waitingBookingCountProvider = Provider.autoDispose.family<int, String>((ref, venueId) =>
    ref
        .watch(venueBookingsProvider(venueId))
        .valueOrNull
        ?.where((b) => b.status == BookingStatus.pending && !b.hasStarted())
        .length ??
    0);

/// A ground's regular bookings (its manager and admins). Invalidate after
/// adding or stopping one.
final regularBookingsProvider = FutureProvider.autoDispose.family<List<RegularBooking>, String>(
    (ref, groundId) => ref.watch(bookingRepositoryProvider).getRegularBookings(groundId));

/// Everyone who has booked at a venue, with their bookings and regular
/// bookings: its manager's records.
final bookingRecordsProvider = FutureProvider.autoDispose.family<List<BookerRecord>, String>((ref, venueId) async {
  final repo = ref.watch(bookingRepositoryProvider);
  final ground = (await ref.watch(venueDetailsProvider(venueId).future))?.grounds.firstOrNull;
  final (bookings, regulars) = await (
    repo.getBookingRecords(venueId),
    ground == null ? Future.value(const <RegularBooking>[]) : repo.getRegularBookings(ground.id),
  ).wait;
  return BookerRecord.from(bookings, regulars);
});

/// The customer has played at this venue, so may review it (as the database checks).
final canReviewVenueProvider = Provider.autoDispose.family<bool, String>((ref, venueId) =>
    ref.watch(myBookingsProvider).valueOrNull?.any((b) => b.venueId == venueId && b.canBeReviewed) ?? false);
