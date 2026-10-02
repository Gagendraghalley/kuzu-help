import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase/supabase_client.dart';
import '../../../core/utils/bhutan_time.dart';
import '../../../shared/models/subscription.dart';

/// Talks to Supabase about grounds' subscriptions (supabase/updates.sql,
/// section 14): their billing history and what admins set for every ground.
/// A ground's manager reads them; only admins change them (the database
/// refuses anyone else). Each ground's current end, kind and fee come with
/// its venues row (Venue.subscription).
class SubscriptionRepository {
  final SupabaseClient _db;
  SubscriptionRepository(this._db);

  /// A ground's free month, free time and payments, latest first.
  Future<List<SubscriptionPeriod>> getPeriods(String venueId) async {
    final rows = await _db
        .from('venue_subscription_periods')
        .select()
        .eq('venue_id', venueId)
        .order('ends_at')
        .limit(120);
    return rows.map(SubscriptionPeriod.fromJson).toList();
  }

  /// Admins (Billing): every ground's free months, free time and payments,
  /// latest recorded first. Managers get only their own.
  Future<List<SubscriptionPeriod>> getAllPeriods() async {
    final rows =
        await _db.from('venue_subscription_periods').select().order('created_at', ascending: false).limit(500);
    return rows.map(SubscriptionPeriod.fromJson).toList();
  }

  /// How managers pay, and the fee new grounds get.
  Future<SubscriptionSettings> getSettings() async {
    final row = await _db.from('subscription_settings').select().maybeSingle();
    return row == null ? const SubscriptionSettings() : SubscriptionSettings.fromJson(row);
  }

  // Admins

  /// The ground's next month, paid: always one month. Postgres error KH409
  /// while more than a week of the current one is left.
  Future<void> recordPayment(
    String venueId, {
    required int amountNu,
    required String method,
    String? reference,
    String? note,
  }) async {
    await _db.rpc('record_subscription_payment', params: {
      'venue': venueId,
      'amount': amountNu,
      'method': method,
      'reference': reference,
      'note': note,
    });
  }

  /// Free time, as long as the admin likes, after what the ground has now.
  Future<void> extendFreePeriod(String venueId, {int months = 0, int days = 0, String? note}) async {
    await _db.rpc('extend_free_period', params: {
      'venue': venueId,
      'add_months': months,
      'add_days': days,
      'note': note,
    });
  }

  /// Takes back free time not had yet: listed until the end of [lastDay] (a
  /// Bhutan day) instead. Postgres error KH410 if that's before the last
  /// paid month ends.
  Future<void> shortenFreeTime(String venueId, {required DateTime lastDay, String? note}) async {
    await _db.rpc('shorten_free_time', params: {
      'venue': venueId,
      'last_day': BhutanTime.isoDate(lastDay),
      'note': note,
    });
  }

  /// Emails a payment's invoice to its ground's manager (again). Postgres
  /// error KH503, saying what's missing, when invoice emails aren't set up
  /// (README); false from a database from before that.
  Future<bool> emailInvoice(String periodId) async =>
      await _db.rpc('email_subscription_invoice', params: {'period': periodId}) == true;

  Future<void> setFee(String venueId, int? feeNu) async {
    await _db.rpc('set_subscription_fee', params: {'venue': venueId, 'fee': feeNu});
  }

  Future<void> saveSettings(SubscriptionSettings settings) async {
    await _db.rpc('set_subscription_settings', params: {
      'fee': settings.defaultFeeNu,
      'how_to_pay': settings.paymentInfo,
    });
  }
}

final subscriptionRepositoryProvider =
    Provider<SubscriptionRepository>((ref) => SubscriptionRepository(ref.watch(supabaseProvider)));
