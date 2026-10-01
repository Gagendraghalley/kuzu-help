/// Ground bookings are in Bhutan time (UTC+6 all year, as in
/// supabase/updates.sql section 13), whatever the phone's own time zone.
///
/// A Bhutan 'day' is a UTC DateTime at midnight whose year, month and day are
/// the Bhutan date. [of] gives an instant as Bhutan wall-clock time, read the
/// same way: its hour is the hour in Bhutan.
class BhutanTime {
  static const offset = Duration(hours: 6);

  /// [instant] as Bhutan wall-clock time (read its fields, don't convert it).
  static DateTime of(DateTime instant) => instant.toUtc().add(offset);

  /// The Bhutan date [instant] falls on.
  static DateTime dayOf(DateTime instant) {
    final t = of(instant);
    return DateTime.utc(t.year, t.month, t.day);
  }

  /// Today in Bhutan.
  static DateTime today({DateTime? now}) => dayOf(now ?? DateTime.now());

  /// The instant it is [hour] o'clock (0 to 24) on the Bhutan [day].
  static DateTime at(DateTime day, int hour) =>
      DateTime.utc(day.year, day.month, day.day, hour).subtract(offset);

  /// [day] as the database's date, e.g. 2026-10-04.
  static String isoDate(DateTime day) =>
      '${day.year}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';

  /// opening_hours.weekday for a Bhutan [day]: 0 = Sunday ... 6 = Saturday.
  static int weekdayOf(DateTime day) => day.weekday % 7;
}
