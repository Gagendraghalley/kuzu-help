import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/models/subscription.dart';
import '../data/subscription_repository.dart';

// Riverpod providers: a ground's billing history, and what admins set for
// every ground. Screens watch these; these call the repositories in ../data/.
// The ground's current subscription comes with it (venueDetailsProvider).

/// A ground's billing history. Invalidate after a payment or free time.
final subscriptionPeriodsProvider = FutureProvider.autoDispose.family<List<SubscriptionPeriod>, String>(
    (ref, venueId) => ref.watch(subscriptionRepositoryProvider).getPeriods(venueId));

/// How managers pay, and the fee new grounds get. Invalidate after saving them.
final subscriptionSettingsProvider =
    FutureProvider.autoDispose<SubscriptionSettings>((ref) => ref.watch(subscriptionRepositoryProvider).getSettings());
