import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/supabase/supabase_client.dart';
import '../../../shared/models/ground.dart';
import '../../../shared/models/ground_booking.dart';
import '../../../shared/models/regular_booking.dart';

/// Talks to Supabase about ground bookings (supabase/updates.sql, section
/// 13). Every change goes through a database function, which checks who may
/// make it; the other person is notified.
class BookingRepository {
  final SupabaseClient _db;
  BookingRepository(this._db);

  /// How long past bookings stay on the manager's list.
  static const _managerHistory = Duration(days: 30);

  String get _userId => _db.auth.currentUser!.id;

  /// The customer's bookings, latest first.
  Future<List<GroundBooking>> getMyBookings() async {
    final rows = await _db
        .from('ground_booking_list')
        .select()
        .eq('booked_by', _userId)
        .eq('kind', BookingKind.customer)
        .order('starts_at')
        .limit(100);
    return rows.map(GroundBooking.fromJson).toList();
  }

  /// The bookings and blocked time at [venueId] (its manager and admins), from the last 30 days on.
  Future<List<GroundBooking>> getVenueBookings(String venueId) async {
    final rows = await _db
        .from('ground_booking_list')
        .select()
        .eq('venue_id', venueId)
        .gte('ends_at', DateTime.now().subtract(_managerHistory).toUtc().toIso8601String())
        .order('starts_at')
        .limit(300);
    return rows.map(GroundBooking.fromJson).toList();
  }

  /// Books [hours] whole hours from [start]; the database works out the price
  /// and checks the time is free and open. [payment] is a PaymentMethod
  /// value; [paymentRef] a journal number. Postgres error 23P01: someone
  /// else has the time; 54000: 3 bookings are already waiting for an answer.
  /// Returns the booking's ID.
  Future<String> book({
    required String groundId,
    required DateTime start,
    required int hours,
    required String phone,
    String? team,
    int? players,
    String payment = PaymentMethod.payAtVenue,
    String? paymentRef,
    String? note,
  }) async {
    final id = await _db.rpc('book_ground', params: {
      'ground': groundId,
      'start_time': start.toUtc().toIso8601String(),
      'hours': hours,
      'phone': phone,
      'team': team,
      'players': players,
      'payment': payment,
      'payment_ref': paymentRef,
      'note': note,
    });
    return id as String;
  }

  /// A BookingStatus value; the database checks who may make each change.
  /// [note] is the venue's message to the customer.
  Future<void> setStatus(String bookingId, String status, {String? note}) async {
    await _db.rpc('set_booking_status', params: {'booking': bookingId, 'new_status': status, 'note': note});
  }

  /// The ground's manager (or an admin) books one of its times for someone who
  /// called: confirmed at once, so everyone sees it as booked (book_by_phone).
  /// Postgres error 23P01: the time is taken; 22023: it isn't one of the
  /// ground's times, or not within the week ahead.
  Future<String> bookByPhone({
    required String groundId,
    required DateTime start,
    required int hours,
    required String name,
    String? phone,
    String? team,
  }) async {
    final id = await _db.rpc('book_by_phone', params: {
      'ground': groundId,
      'start_time': start.toUtc().toIso8601String(),
      'hours': hours,
      'name': name,
      'phone': phone,
      'team': team,
    });
    return id as String;
  }

  /// Everyone who has booked at [venueId], in the app or by phone, latest
  /// first: the manager's records (its manager and admins).
  Future<List<GroundBooking>> getBookingRecords(String venueId) async {
    final rows = await _db
        .from('ground_booking_list')
        .select()
        .eq('venue_id', venueId)
        .inFilter('kind', [BookingKind.customer, BookingKind.phone])
        .order('starts_at', ascending: false)
        .limit(1000);
    return rows.map(GroundBooking.fromJson).toList();
  }

  /// The ground's regular bookings (its manager and admins), by day and time.
  Future<List<RegularBooking>> getRegularBookings(String groundId) async {
    final rows = await _db
        .from('ground_regular_bookings')
        .select()
        .eq('ground_id', groundId)
        .order('weekday')
        .order('start_hour');
    return rows.map(RegularBooking.fromJson).toList();
  }

  /// Holds the ground's [slots] every week for someone who always plays then,
  /// one or more a week (add_regular_bookings): all of them, or none.
  /// Postgres error 23P01: another regular booking, or a booking in the week
  /// ahead, has some of that time.
  Future<List<String>> addRegularBookings({
    required String groundId,
    required List<TimeSlot> slots,
    required String name,
    String? phone,
    String? team,
  }) async {
    final ids = await _db.rpc('add_regular_bookings', params: {
      'ground': groundId,
      'slots': [for (final slot in slots) slot.toJson()],
      'name': name,
      'phone': phone,
      'team': team,
    });
    return (ids as List).cast<String>();
  }

  /// Changes a regular booking's day and time, or who has it
  /// (update_regular_booking). Postgres errors as [addRegularBooking].
  Future<void> updateRegularBooking({
    required String regularId,
    required TimeSlot slot,
    required String name,
    String? phone,
    String? team,
  }) async {
    await _db.rpc('update_regular_booking', params: {
      'regular': regularId,
      'weekday': slot.weekday,
      'start_hour': slot.startHour,
      'end_hour': slot.endHour,
      'name': name,
      'phone': phone,
      'team': team,
    });
  }

  /// Holds a confirmed booking's day and time every week from now on, for
  /// the same person (make_booking_regular). Postgres error 23P01: another
  /// regular booking, or someone else's booking in the week ahead, has some
  /// of that time; 22023: it's no longer one of the ground's times.
  Future<String> makeRegular(String bookingId) async {
    final id = await _db.rpc('make_booking_regular', params: {'booking': bookingId});
    return id as String;
  }

  /// Removes a regular booking: the time is free again.
  Future<void> removeRegularBooking(String regularId) async {
    await _db.rpc('remove_regular_booking', params: {'regular': regularId});
  }

  /// The venue's manager (or an admin) blocks time on a ground. Postgres error 23P01: a booking
  /// has some of it.
  Future<void> blockTime({
    required String groundId,
    required DateTime start,
    required DateTime end,
    String? reason,
  }) async {
    await _db.rpc('block_ground_time', params: {
      'ground': groundId,
      'start_time': start.toUtc().toIso8601String(),
      'end_time': end.toUtc().toIso8601String(),
      'reason': reason,
    });
  }

  /// The customer's journal number for an advance paid by mBoB or mPay.
  Future<void> setPaymentRef(String bookingId, String? reference) async {
    await _db.rpc('set_booking_payment_ref', params: {'booking': bookingId, 'payment_ref': reference});
  }

  /// The venue's manager (or an admin) marks the booking paid, or not paid after all.
  Future<void> setPaid(String bookingId, bool paid) async {
    await _db.rpc('set_booking_paid', params: {'booking': bookingId, 'paid': paid});
  }
}

final bookingRepositoryProvider = Provider<BookingRepository>((ref) => BookingRepository(ref.watch(supabaseProvider)));
