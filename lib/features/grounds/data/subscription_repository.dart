import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase/supabase_client.dart';
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
