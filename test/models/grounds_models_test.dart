import 'package:bhutan_services/core/constants/app_constants.dart';
import 'package:bhutan_services/core/strings/app_strings.dart';
import 'package:bhutan_services/core/utils/bhutan_time.dart';
import 'package:bhutan_services/core/utils/price_utils.dart';
import 'package:bhutan_services/shared/models/ground.dart';
import 'package:bhutan_services/shared/models/ground_booking.dart';
import 'package:bhutan_services/shared/models/venue.dart';
import 'package:flutter_test/flutter_test.dart';

// Sports grounds: Bhutan time, prices and the rows the app reads
// (supabase/updates.sql, section 13).

void main() {
  final sunday = DateTime.utc(2026, 10, 4); // a Sunday in Bhutan

  group('BhutanTime', () {
    test('an hour on a Bhutan day is 6 hours earlier in UTC', () {
      expect(BhutanTime.at(sunday, 18), DateTime.utc(2026, 10, 4, 12));
      expect(BhutanTime.at(sunday, 24), DateTime.utc(2026, 10, 4, 18)); // midnight
    });

    test('late evening UTC is already the next day in Bhutan', () {
      expect(BhutanTime.dayOf(DateTime.utc(2026, 10, 4, 20)), DateTime.utc(2026, 10, 5));
      expect(BhutanTime.today(now: DateTime.utc(2026, 10, 4, 17, 59)), sunday);
    });

    test('weekdays count from Sunday, as the database does', () {
      expect(BhutanTime.weekdayOf(sunday), 0);
      expect(BhutanTime.weekdayOf(DateTime.utc(2026, 10, 10)), 6);
      expect(BhutanTime.isoDate(sunday), '2026-10-04');
    });
  });

  group('booking times read in Bhutan time', () {
    test('hours', () {
      expect([0, 6, 12, 17, 24].map(AppStrings.hourLabel), ['12 am', '6 am', '12 pm', '5 pm', '12 am']);
    });

    test('a booking on one day, and one that ends at midnight', () {
      expect(AppStrings.bookingTime(BhutanTime.at(sunday, 18), BhutanTime.at(sunday, 20)), 'Sun 4 Oct, 6 pm – 8 pm');
      expect(AppStrings.bookingTime(BhutanTime.at(sunday, 22), BhutanTime.at(sunday, 24)), 'Sun 4 Oct, 10 pm – 12 am');
    });

    test('a block that runs over several days names both', () {
      expect(
        AppStrings.bookingTime(BhutanTime.at(sunday, 8), BhutanTime.at(DateTime.utc(2026, 10, 6), 18)),
        'Sun 4 Oct 8 am – Tue 6 Oct 6 pm',
      );
    });
  });

  test('timetable times are as short as reads clearly', () {
    expect(AppStrings.hoursShort(18, 20), '6 – 8 pm');
    expect(AppStrings.hoursShort(8, 10), '8 – 10 am');
    expect(AppStrings.hoursShort(12, 14), '12 – 2 pm');
    expect(AppStrings.hoursShort(0, 2), '12 – 2 am');
    expect(AppStrings.hoursShort(22, 24), '10 pm – 12 am'); // into the next day
    expect(AppStrings.hoursShort(11, 13), '11 am – 1 pm');
  });

  test('PriceUtils.nu groups thousands', () {
    expect([0, 950, 1500, 100000].map(PriceUtils.nu), ['Nu. 0', 'Nu. 950', 'Nu. 1,500', 'Nu. 100,000']);
  });

  group('Ground', () {
    // Sundays only: 6 to 9 pm, 8 to 10 pm (overlapping) and 10 pm to midnight.
    const ground = Ground(
      id: 'g',
      venueId: 'v',
      name: 'Changli Futsal',
      pricePerHourNu: 1000,
      eveningPriceNu: 1500,
      eveningFromHour: 17,
      slots: [
        TimeSlot(weekday: 0, startHour: 22, endHour: 24),
        TimeSlot(weekday: 0, startHour: 18, endHour: 21),
        TimeSlot(weekday: 0, startHour: 20, endHour: 22),
      ],
    );

    test('each hour from the evening costs the evening price, as book_ground works it out', () {
      expect(ground.priceFor(10, 3), 3000);
      expect(ground.priceFor(16, 2), 2500);
      expect(ground.priceFor(18, 2), 3000);
      expect(ground.priceOf(const TimeSlot(weekday: 0, startHour: 18, endHour: 21)), 4500);
      // A time that runs into the night: one hour at each price.
      expect(ground.priceOf(const TimeSlot(weekday: 0, startHour: 16, endHour: 18)), 2500);
      expect(AppStrings.groundPrice(1000, eveningPrice: 1500, eveningFrom: 18),
          'Nu. 1,000/hour · Nu. 1,500/hour at night, from 6 pm');
      expect(AppStrings.groundPrice(1000, eveningFrom: 18), 'Nu. 1,000/hour');
      expect(const Ground(id: 'g', venueId: 'v', name: 'B', pricePerHourNu: 800).priceFor(18, 2), 1600);
    });

    test('time slots by Bhutan day, earliest first; a day without any is closed', () {
      expect([for (final s in ground.slotsOn(sunday)) (s.startHour, s.endHour)], [(18, 21), (20, 22), (22, 24)]);
      expect(ground.slotsOn(DateTime.utc(2026, 10, 5)), isEmpty);
    });

    test('fromJson reads the embedded time slots, earliest first', () {
      final g = Ground.fromJson({
        'id': 'g1',
        'venue_id': 'v1',
        'name': 'Main ground',
        'sport': 'football',
        'price_per_hour_nu': 2500,
        'evening_price_nu': null,
        'evening_from_hour': 17,
        'is_active': true,
        'ground_time_slots': [
          {'weekday': 6, 'start_hour': 20, 'end_hour': 24},
          {'weekday': 6, 'start_hour': 7, 'end_hour': 9},
        ],
      });
      expect((g.sport, g.pricePerHourNu), (Sport.football, 2500));
      expect([for (final s in g.slots) (s.weekday, s.startHour, s.endHour)], [(6, 7, 9), (6, 20, 24)]);
      expect(g.slots.first.toJson(), {'weekday': 6, 'start_hour': 7, 'end_hour': 9});
    });

    test('the week reads Monday first, with days in a row that have the same times together', () {
      String show(Ground g) => [
            for (final d in g.week)
              '${AppStrings.weekdays(d.from, d.to)}: '
                  '${d.slots.isEmpty ? AppStrings.closed : d.slots.map((s) => AppStrings.hoursRange(s.startHour, s.endHour)).join(', ')}',
          ].join('; ');

      final g = Ground(id: 'g', venueId: 'v', name: 'A', pricePerHourNu: 1000, slots: [
        for (var day = 1; day <= 5; day++) ...[
          TimeSlot(weekday: day, startHour: 18, endHour: 20),
          TimeSlot(weekday: day, startHour: 20, endHour: 22),
        ],
        const TimeSlot(weekday: 6, startHour: 7, endHour: 24), // Saturday until midnight
        // Sunday: closed
      ]);
      expect(show(g), 'Mon – Fri: 6 pm – 8 pm, 8 pm – 10 pm; Sat: 7 am – 12 am; Sun: Closed');
      expect(show(ground), 'Mon – Sat: Closed; Sun: 6 pm – 9 pm, 8 pm – 10 pm, 10 pm – 12 am');

      final same = Ground(id: 'g', venueId: 'v', name: 'A', pricePerHourNu: 1000, slots: [
        for (var day = 0; day < 7; day++) TimeSlot(weekday: day, startHour: 6, endHour: 8),
      ]);
      expect((same.week.single.from, same.week.single.to), (1, 0)); // shown as 'Every day'
    });
  });

  test('Venue.fromJson reads a venue_directory row merged with the venues row and its manager', () {
    final listed = {
      'id': 'v1',
      'manager_id': 'm1',
      'venue_type': 'sports_ground',
      'name': 'Changli Futsal',
      'dzongkhag': 'Thimphu',
      'town': 'Changzamtog',
      'phone': '+97517111111',
      'auto_confirm': true,
      'from_price_nu': 1000,
      'ground_count': 2,
      'sports': ['futsal'],
      'avg_rating': 4.5,
      'review_count': 3,
    };
    final managed = {
      ...listed,
      'is_active': false,
      'manager': {'full_name': 'Tashi Dorji', 'email': 'tashi@example.com', 'phone': null, 'is_active': true},
    }..remove('from_price_nu');
    final v = Venue.fromJson({...listed, ...managed});
    expect((v.location, v.fromPriceNu, v.avgRating, v.managerName, v.isActive, v.isListed),
        ('Changzamtog, Thimphu', 1000, 4.5, 'Tashi Dorji', false, false));

    final unmanaged = Venue.fromJson({...managed, 'manager_id': null, 'manager': null, 'is_active': true});
    expect((unmanaged.hasManager, unmanaged.isListed), (false, false));
  });

  group('GroundBooking', () {
    GroundBooking read(Map<String, dynamic> changes) => GroundBooking.fromJson({
          'id': 'b1',
          'ground_id': 'g1',
          'booked_by': 'c1',
          'kind': 'customer',
          'starts_at': '2026-10-04T12:00:00+00:00',
          'ends_at': '2026-10-04T14:00:00+00:00',
          'status': 'pending',
          'price_nu': 3000,
          'contact_name': 'Karma',
          'payment_method': 'mbob_transfer',
          'payment_status': 'deposit_claimed',
          'created_at': '2026-10-01T08:00:00+00:00',
          'ground_name': 'Court A',
          'sport': 'futsal',
          'venue_id': 'v1',
          'manager_id': 'm1',
          'venue_name': 'Changli Futsal',
          'venue_dzongkhag': 'Thimphu',
          'venue_phone': '+97517111111',
          'free_cancel_hours': 24,
          ...changes,
        });

    test('fromJson reads a ground_booking_list row', () {
      final b = read({});
      expect((b.hours, b.priceNu, b.isOpen, b.paidAdvanceByTransfer), (2, 3000, true, true));
      expect(AppStrings.bookingTime(b.startsAt, b.endsAt), 'Sun 4 Oct, 6 pm – 8 pm');
    });

    test('late cancelling starts free_cancel_hours before it', () {
      final b = read({});
      expect(b.isLateToCancel(DateTime.utc(2026, 10, 3, 11)), isFalse);
      expect(b.isLateToCancel(DateTime.utc(2026, 10, 3, 13)), isTrue);
    });

    test('only a played booking can be reviewed; an unanswered one reads as expired', () {
      expect(read({'status': 'confirmed', 'starts_at': '2026-09-01T12:00:00+00:00', 'ends_at': '2026-09-01T13:00:00+00:00'})
          .canBeReviewed, isTrue);
      expect(read({'status': 'confirmed', 'starts_at': '2099-10-04T12:00:00+00:00', 'ends_at': '2099-10-04T13:00:00+00:00'})
          .canBeReviewed, isFalse); // not played yet
      expect(AppStrings.bookingStatusLabel(BookingStatus.cancelled, expired: true), 'Expired');
    });
  });

  test('booking notifications say when and where', () {
    final data = {
      'customer_name': 'Karma',
      'venue_name': 'Changli Futsal',
      'ground_name': 'Court A',
      'starts_at': '2026-10-04T12:00:00+00:00',
      'hours': 2,
      'status': 'pending',
    };
    expect(AppStrings.notificationTitle(NotificationTypes.bookingNew, data), 'New booking request from Karma');
    expect(AppStrings.notificationBody(NotificationTypes.bookingNew, data),
        'Court A · Sun 4 Oct, 6 pm – 8 pm · Tap to confirm or reject.');
    expect(AppStrings.notificationTitle(NotificationTypes.bookingCancelled, {...data, 'by': 'owner'}),
        'Changli Futsal cancelled your booking');
    expect(AppStrings.notificationBody(NotificationTypes.bookingCancelled, {...data, 'by': 'owner', 'note': 'Rain'}),
        'Rain');
  });
}
