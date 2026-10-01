import '../../core/constants/app_constants.dart';
import '../../core/utils/bhutan_time.dart';

/// A time a ground can be booked on one day of the week (ground_time_slots):
/// customers book the whole slot. A day can have several, and they may
/// overlap (6-9 pm and 8-10 pm); a day with none is closed.
class TimeSlot {
  final int weekday; // 0 = Sunday ... 6 = Saturday
  final int startHour; // 0 to 23
  final int endHour; // 1 to 24 (midnight)

  const TimeSlot({required this.weekday, required this.startHour, required this.endHour});

  factory TimeSlot.fromJson(Map<String, dynamic> json) => TimeSlot(
        weekday: json['weekday'] as int,
        startHour: json['start_hour'] as int,
        endHour: json['end_hour'] as int,
      );

  Map<String, dynamic> toJson() => {'weekday': weekday, 'start_hour': startHour, 'end_hour': endHour};

  int get hours => endHour - startHour;

  /// The same times on another day.
  TimeSlot on(int weekday) => TimeSlot(weekday: weekday, startHour: startHour, endHour: endHour);

  /// Earliest first; the shorter of two that start together first.
  static int byTime(TimeSlot a, TimeSlot b) =>
      a.startHour != b.startHour ? a.startHour - b.startHour : a.endHour - b.endHour;

  @override
  bool operator ==(Object other) =>
      other is TimeSlot && other.weekday == weekday && other.startHour == startHour && other.endHour == endHour;

  @override
  int get hashCode => Object.hash(weekday, startHour, endHour);
}

/// Maps the grounds table, with its time slots (supabase/updates.sql,
/// section 13). In the app a venue is a 'ground' with one of these: its
/// type, price and timings. Prices are whole Ngultrum.
class Ground {
  final String id;
  final String venueId;
  final String name; // the venue's; not shown
  final String sport; // a Sport value
  final String? format; // e.g. 5-a-side
  final String? surface; // e.g. Artificial turf
  final bool isIndoor;
  final bool hasFloodlights;
  final int pricePerHourNu;
  final int? eveningPriceNu; // from [eveningFromHour]
  final int eveningFromHour;
  final bool isActive; // false: not taking bookings
  final List<TimeSlot> slots; // every day's; a day with none is closed

  const Ground({
    required this.id,
    required this.venueId,
    required this.name,
    this.sport = Sport.futsal,
    this.format,
    this.surface,
    this.isIndoor = false,
    this.hasFloodlights = true,
    required this.pricePerHourNu,
    this.eveningPriceNu,
    this.eveningFromHour = 17,
    this.isActive = true,
    this.slots = const [],
  });

  /// grounds columns plus the time slots.
  static const columns = '*, ground_time_slots(weekday, start_hour, end_hour)';

  factory Ground.fromJson(Map<String, dynamic> json) => Ground(
        id: json['id'] as String,
        venueId: json['venue_id'] as String,
        name: json['name'] as String? ?? '',
        sport: json['sport'] as String? ?? Sport.futsal,
        format: json['format'] as String?,
        surface: json['surface'] as String?,
        isIndoor: json['is_indoor'] as bool? ?? false,
        hasFloodlights: json['has_floodlights'] as bool? ?? true,
        pricePerHourNu: json['price_per_hour_nu'] as int,
        eveningPriceNu: json['evening_price_nu'] as int?,
        eveningFromHour: json['evening_from_hour'] as int? ?? 17,
        isActive: json['is_active'] as bool? ?? true,
        slots: [
          for (final row in (json['ground_time_slots'] as List? ?? const []))
            TimeSlot.fromJson(row as Map<String, dynamic>),
        ]..sort(TimeSlot.byTime),
      );

  /// The price of the hour starting at [hour] o'clock, as book_ground works it out.
  int priceForHour(int hour) {
    final evening = eveningPriceNu;
    return evening != null && hour >= eveningFromHour ? evening : pricePerHourNu;
  }

  /// The price of [hours] hours from [startHour] o'clock.
  int priceFor(int startHour, int hours) {
    var total = 0;
    for (var h = startHour; h < startHour + hours; h++) {
      total += priceForHour(h);
    }
    return total;
  }

  int priceOf(TimeSlot slot) => priceFor(slot.startHour, slot.hours);

  /// The slots on a day of the week (0 = Sunday), earliest first.
  List<TimeSlot> slotsOnWeekday(int weekday) => [
        for (final s in slots)
          if (s.weekday == weekday) s,
      ]..sort(TimeSlot.byTime);

  /// The slots on the Bhutan [day], earliest first; none: closed.
  List<TimeSlot> slotsOn(DateTime day) => slotsOnWeekday(BhutanTime.weekdayOf(day));

  /// The week, Monday first, for showing: days in a row with the same slots
  /// go together, so 'Mon – Fri: 6 pm – 8 pm, 8 pm – 10 pm'. [slots] empty:
  /// closed. One entry: the same every day.
  List<({int from, int to, List<TimeSlot> slots})> get week {
    final days = <({int from, int to, List<TimeSlot> slots})>[];
    bool same(List<TimeSlot> a, List<TimeSlot> b) =>
        a.length == b.length &&
        [for (var i = 0; i < a.length; i++) a[i].startHour == b[i].startHour && a[i].endHour == b[i].endHour]
            .every((equal) => equal);
    for (final weekday in const [1, 2, 3, 4, 5, 6, 0]) {
      final today = slotsOnWeekday(weekday);
      final last = days.lastOrNull;
      if (last != null && same(last.slots, today)) {
        days.last = (from: last.from, to: weekday, slots: last.slots);
      } else {
        days.add((from: weekday, to: weekday, slots: today));
      }
    }
    return days;
  }
}

/// A ground's type and price, as the admin (registering it) or its manager
/// fills them in. [id] is null until the ground has them.
class GroundDraft {
  final String? id;
  final String name; // the venue's
  final String sport;
  final String? format;
  final String? surface;
  final bool isIndoor;
  final bool hasFloodlights;
  final int pricePerHourNu;
  final int? eveningPriceNu;
  final int eveningFromHour;

  const GroundDraft({
    this.id,
    required this.name,
    required this.sport,
    this.format,
    this.surface,
    this.isIndoor = false,
    this.hasFloodlights = true,
    required this.pricePerHourNu,
    this.eveningPriceNu,
    this.eveningFromHour = 17,
  });

  /// The grounds columns the manager may change (not venue_id once it's made).
  Map<String, dynamic> toJson() => {
        'name': name.length > 60 ? name.substring(0, 60).trim() : name, // the column's limit
        'sport': sport,
        'format': format,
        'surface': surface,
        'is_indoor': isIndoor,
        'has_floodlights': hasFloodlights,
        'price_per_hour_nu': pricePerHourNu,
        'evening_price_nu': eveningPriceNu,
        'evening_from_hour': eveningFromHour,
        'is_active': true,
      };
}
