import 'dart:math';

import '../../core/constants/app_constants.dart';
import '../../core/utils/bhutan_time.dart';

/// A ground's subscription (supabase/updates.sql, section 14), from its
/// venues row: players can find and book it until [endsAt], a Bhutan
/// midnight. Only admins change it; its manager reads it.
class VenueSubscription {
  final DateTime endsAt;
  final String kind; // a SubscriptionKind value: the latest period's
  final int? feeNu; // the ground's monthly fee; null until an admin sets one

  const VenueSubscription({required this.endsAt, required this.kind, this.feeNu});

  bool isEnded({DateTime? now}) => !endsAt.isAfter(now ?? DateTime.now());

  /// The last Bhutan day it covers.
  DateTime get lastDay => lastDayBefore(endsAt);

  /// Days from today (Bhutan) to [lastDay]: 0 on the last day, negative once it has ended.
  int daysLeft({DateTime? now}) => lastDay.difference(BhutanTime.today(now: now)).inDays;

  /// An admin may record the next month's payment: one month at a time, in
  /// the last [AppConstants.subscriptionNoticeDays] days or once it has
  /// ended (record_subscription_payment).
  bool canPayNextMonth({DateTime? now}) => !endsAt.isAfter(
      (now ?? DateTime.now()).add(const Duration(days: AppConstants.subscriptionNoticeDays)));

  /// The first day the next month can be recorded (while [canPayNextMonth] is false).
  DateTime get payableFrom =>
      BhutanTime.dayOf(endsAt.subtract(const Duration(days: AppConstants.subscriptionNoticeDays)));

  /// In its last days: the manager is reminded to pay for the next month.
  bool endsSoon({DateTime? now}) => !isEnded(now: now) && canPayNextMonth(now: now);

  /// The next period of [months] and [days], as the database adds it: from
  /// where this one ends, or from now once it has ended.
  ({DateTime start, DateTime end}) next({int months = 0, int days = 0, DateTime? now}) {
    final at = now ?? DateTime.now();
    final start = endsAt.isAfter(at) ? endsAt : at;
    return (start: start, end: periodEnd(start, months: months, days: days));
  }

  /// [from] plus [months] and [days] in Bhutan time, rounded up to the next
  /// Bhutan midnight, as subscription_period_end does: 31 Jan plus a month
  /// ends after 28 Feb (or 29).
  static DateTime periodEnd(DateTime from, {int months = 0, int days = 0}) {
    final t = BhutanTime.of(from);
    final month = t.month + months;
    final lastOfMonth = DateTime.utc(t.year, month + 1, 0).day; // DateTime.utc rolls months over into years
    final moved = DateTime.utc(
            t.year, month, min(t.day, lastOfMonth), t.hour, t.minute, t.second, t.millisecond, t.microsecond)
        .add(Duration(days: days));
    final midnight = DateTime.utc(moved.year, moved.month, moved.day);
    return BhutanTime.at(moved == midnight ? midnight : midnight.add(const Duration(days: 1)), 0);
  }

  /// The Bhutan day a period ending at [end] (a Bhutan midnight) ends on.
  static DateTime lastDayBefore(DateTime end) => BhutanTime.dayOf(end.subtract(const Duration(seconds: 1)));
}

/// One period of a ground's subscription, for its billing history
/// (venue_subscription_periods): its free month, free time an admin gave,
/// or a month paid for.
class SubscriptionPeriod {
  final String id;
  final String venueId;
  final String kind; // a SubscriptionKind value
  final DateTime startsAt;
  final DateTime endsAt;
  final int? amountNu; // paid ones
  final String? paymentMethod; // a BillingMethod value; paid ones
  final String? paymentReference; // the mBoB / mPay journal number
  final String? note;
  final DateTime createdAt;

  const SubscriptionPeriod({
    required this.id,
    required this.venueId,
    required this.kind,
    required this.startsAt,
    required this.endsAt,
    this.amountNu,
    this.paymentMethod,
    this.paymentReference,
    this.note,
    required this.createdAt,
  });

  factory SubscriptionPeriod.fromJson(Map<String, dynamic> json) => SubscriptionPeriod(
        id: json['id'] as String,
        venueId: json['venue_id'] as String,
        kind: json['kind'] as String,
        startsAt: DateTime.parse(json['starts_at'] as String),
        endsAt: DateTime.parse(json['ends_at'] as String),
        amountNu: json['amount_nu'] as int?,
        paymentMethod: json['payment_method'] as String?,
        paymentReference: json['payment_reference'] as String?,
        note: json['note'] as String?,
        createdAt: DateTime.parse(json['created_at'] as String),
      );

  DateTime get firstDay => BhutanTime.dayOf(startsAt);
  DateTime get lastDay => VenueSubscription.lastDayBefore(endsAt);
}

/// What admins set once for every ground (subscription_settings).
class SubscriptionSettings {
  final int? defaultFeeNu; // the monthly fee new grounds get
  final String? paymentInfo; // how managers pay Kuzu Help

  const SubscriptionSettings({this.defaultFeeNu, this.paymentInfo});

  factory SubscriptionSettings.fromJson(Map<String, dynamic> json) => SubscriptionSettings(
        defaultFeeNu: json['default_fee_nu'] as int?,
        paymentInfo: json['payment_info'] as String?,
      );
}
