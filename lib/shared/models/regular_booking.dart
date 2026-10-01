import 'ground.dart';
import 'ground_booking.dart';

/// The same time every week, held for someone who always plays then
/// (ground_regular_bookings, supabase/updates.sql section 13). Everyone
/// sees the time as a regular booking; only the ground's manager and admins
/// read who it is.
class RegularBooking {
  final String id;
  final String groundId;
  final int weekday; // 0 = Sunday ... 6 = Saturday
  final int startHour;
  final int endHour; // 24: midnight
  final String name;
  final String? phone; // +975XXXXXXXX
  final String? teamName;

  const RegularBooking({
    required this.id,
    required this.groundId,
    required this.weekday,
    required this.startHour,
    required this.endHour,
    required this.name,
    this.phone,
    this.teamName,
  });

  factory RegularBooking.fromJson(Map<String, dynamic> json) => RegularBooking(
        id: json['id'] as String,
        groundId: json['ground_id'] as String,
        weekday: json['weekday'] as int,
        startHour: json['start_hour'] as int,
        endHour: json['end_hour'] as int,
        name: json['name'] as String? ?? '',
        phone: json['phone'] as String?,
        teamName: json['team_name'] as String?,
      );

  TimeSlot get slot => TimeSlot(weekday: weekday, startHour: startHour, endHour: endHour);
}

/// Someone who has booked the ground, for its manager's records: their
/// bookings, latest first, and their regular bookings, under the name they
/// gave last. People are told apart by phone number, or by name without one.
class BookerRecord {
  final String name;
  final String? phone;
  final List<GroundBooking> bookings;
  final List<RegularBooking> regulars;

  const BookerRecord({required this.name, this.phone, this.bookings = const [], this.regulars = const []});

  bool get isRegular => regulars.isNotEmpty;

  /// Their latest booking's start, or null with none (only a regular booking).
  DateTime? get lastBooked => bookings.firstOrNull?.startsAt;

  /// Everyone in [bookings] (customers' and those taken by phone; not
  /// blocked time) and [regulars]: regulars first, then the latest to book.
  static List<BookerRecord> from(List<GroundBooking> bookings, List<RegularBooking> regulars) {
    String keyOf(String name, String? phone) => phone ?? 'name:${name.trim().toLowerCase()}';
    final byKey = <String, ({String name, String? phone, List<GroundBooking> bookings, List<RegularBooking> regulars})>{};
    final latestFirst = bookings.where((b) => !b.isBlock).toList()..sort((a, b) => b.startsAt.compareTo(a.startsAt));
    for (final b in latestFirst) {
      final entry = byKey.putIfAbsent(
          keyOf(b.contactName, b.contactPhone), () => (name: b.contactName, phone: b.contactPhone, bookings: [], regulars: []));
      entry.bookings.add(b);
    }
    for (final r in regulars) {
      final entry = byKey.putIfAbsent(keyOf(r.name, r.phone), () => (name: r.name, phone: r.phone, bookings: [], regulars: []));
      entry.regulars.add(r);
    }
    final records = [
      for (final e in byKey.values) BookerRecord(name: e.name, phone: e.phone, bookings: e.bookings, regulars: e.regulars),
    ];
    return records
      ..sort((a, b) {
        if (a.isRegular != b.isRegular) return a.isRegular ? -1 : 1;
        final (x, y) = (a.lastBooked, b.lastBooked);
        if (x == null || y == null) return x == null ? (y == null ? 0 : 1) : -1;
        return y.compareTo(x);
      });
  }
}
