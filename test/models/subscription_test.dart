import 'package:bhutan_services/core/constants/app_constants.dart';
import 'package:bhutan_services/core/utils/bhutan_time.dart';
import 'package:bhutan_services/shared/models/subscription.dart';
import 'package:bhutan_services/shared/models/venue.dart';
import 'package:flutter_test/flutter_test.dart';

/// [hour]:[minute] in Bhutan on that day.
DateTime bt(int year, int month, int day, [int hour = 0, int minute = 0]) =>
    DateTime.utc(year, month, day, hour, minute).subtract(BhutanTime.offset);

void main() {
  group('periods end at a Bhutan midnight, as subscription_period_end in updates.sql', () {
    test('a part day is rounded up, so the first day counts whole', () {
      expect(VenueSubscription.periodEnd(bt(2026, 10, 2, 15, 47), months: 1), bt(2026, 11, 3));
    });

    test('a period from a midnight (the one before) ends at a midnight', () {
      expect(VenueSubscription.periodEnd(bt(2026, 11, 3), months: 1), bt(2026, 12, 3));
      expect(VenueSubscription.periodEnd(bt(2026, 12, 15), months: 1), bt(2027, 1, 15)); // into the next year
      expect(VenueSubscription.periodEnd(bt(2026, 10, 2), months: 12), bt(2027, 10, 2));
    });

    test('a month from the 31st ends after the last day of a shorter month', () {
      expect(VenueSubscription.periodEnd(bt(2027, 1, 31, 10), months: 1), bt(2027, 3, 1)); // last day 28 Feb
      expect(VenueSubscription.periodEnd(bt(2028, 1, 31, 10), months: 1), bt(2028, 3, 1)); // last day 29 Feb
      expect(VenueSubscription.lastDayBefore(bt(2027, 3, 1)), DateTime.utc(2027, 2, 28));
    });

    test('free time can be days', () {
      expect(VenueSubscription.periodEnd(bt(2026, 10, 2), days: 7), bt(2026, 10, 9));
      expect(VenueSubscription.periodEnd(bt(2026, 10, 2), days: 14), bt(2026, 10, 16));
    });
  });

  group('a subscription whose last day is Mon 2 Nov', () {
    final s = VenueSubscription(endsAt: bt(2026, 11, 3), kind: SubscriptionKind.trial, feeNu: 1500);

    test('counts the days left in Bhutan, 0 on the last day', () {
      expect(s.lastDay, DateTime.utc(2026, 11, 2));
      expect(s.daysLeft(now: bt(2026, 10, 2, 15, 47)), 31);
      expect(s.daysLeft(now: bt(2026, 11, 2, 23, 59)), 0);
      expect(s.isEnded(now: bt(2026, 11, 2, 23, 59)), isFalse);
      expect(s.isEnded(now: bt(2026, 11, 3)), isTrue);
      expect(s.daysLeft(now: bt(2026, 11, 5)), -3);
    });

    test('the next month can be paid in its last 7 days only: one month at a time', () {
      expect(s.canPayNextMonth(now: bt(2026, 10, 26, 23, 59)), isFalse);
      expect(s.payableFrom, DateTime.utc(2026, 10, 27));
      expect(s.canPayNextMonth(now: bt(2026, 10, 27)), isTrue);
      expect(s.endsSoon(now: bt(2026, 10, 27)), isTrue);
      expect(s.endsSoon(now: bt(2026, 10, 26)), isFalse);
      // Once it has ended it can still be paid, but it no longer 'ends soon'.
      expect((s.canPayNextMonth(now: bt(2026, 11, 10)), s.endsSoon(now: bt(2026, 11, 10))), (true, false));
    });

    test('the next period starts where it ends, or today once it has ended', () {
      final early = s.next(months: 1, now: bt(2026, 10, 30));
      expect((early.start, early.end), (bt(2026, 11, 3), bt(2026, 12, 3)));
      final late = s.next(months: 1, now: bt(2026, 11, 5, 10));
      expect((late.start, late.end), (bt(2026, 11, 5, 10), bt(2026, 12, 6))); // the time in between isn't charged
    });
  });

  group('Venue.subscription', () {
    final managed = {
      'id': 'v1',
      'manager_id': 'm1',
      'name': 'Changli Futsal',
      'dzongkhag': 'Thimphu',
      'phone': '+97517111111',
      'is_active': true,
      'manager': {'full_name': 'Tashi Dorji', 'email': 'tashi@example.com', 'phone': null, 'is_active': true},
    };

    test('comes with the venues row; once it has ended the ground is not listed', () {
      final ends = DateTime.now().add(const Duration(days: 10)).toUtc();
      final v = Venue.fromJson({
        ...managed,
        'subscription_ends_at': ends.toIso8601String(),
        'subscription_kind': 'paid',
        'subscription_fee_nu': 1500,
      });
      final s = v.subscription!;
      expect((s.endsAt, s.kind, s.feeNu, v.subscriptionEnded, v.isListed), (ends, SubscriptionKind.paid, 1500, false, true));

      final ended = Venue.fromJson({
        ...managed,
        'subscription_ends_at': DateTime.now().subtract(const Duration(hours: 1)).toUtc().toIso8601String(),
        'subscription_kind': 'trial',
      });
      expect((ended.subscriptionEnded, ended.isListed, ended.subscription!.feeNu), (true, false, null));
    });

    test('venue_directory rows have none: every listed ground is subscribed', () {
      final listed = Venue.fromJson({...managed}..remove('manager'));
      expect((listed.subscription, listed.subscriptionEnded, listed.isListed), (null, false, true));
    });
  });
}
