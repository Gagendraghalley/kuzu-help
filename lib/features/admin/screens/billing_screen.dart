import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/router/route_names.dart';
import '../../../core/strings/app_strings.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/bhutan_time.dart';
import '../../../core/utils/price_utils.dart';
import '../../../shared/models/subscription.dart';
import '../../../shared/models/venue.dart';
import '../../../shared/widgets/async_view.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/info_note.dart';
import '../../grounds/providers/subscription_providers.dart';
import '../../grounds/providers/venue_providers.dart';
import '../../grounds/screens/subscription_screen.dart';
import '../../grounds/widgets/status_pill.dart';
import '../../grounds/widgets/subscription_period_tile.dart';
import '../widgets/billing_settings_sheet.dart';

/// Admin (Settings -> Billing): every ground's subscription and billing in
/// one place.
/// Purpose: Which grounds have to pay (ended, or in their last 7 days), are
/// on free time or are paid; record a payment straight from the list; look
/// back over every payment and free time given, of every ground.
/// Backend: The venues rows (allVenuesProvider) and
/// venue_subscription_periods (allSubscriptionPeriodsProvider). A ground's
/// own Subscription page does the rest: free time, its fee, its history.
/// Done when: An admin sees at a glance who to chase, and records a payment
/// in a few taps.
class BillingScreen extends ConsumerStatefulWidget {
  const BillingScreen({super.key});

  @override
  ConsumerState<BillingScreen> createState() => _BillingScreenState();
}

/// Which grounds the list shows. Each ground is in one of the last three.
enum _Filter { all, toPay, free, paid }

class _BillingScreenState extends ConsumerState<BillingScreen> {
  bool _history = false;
  _Filter _filter = _Filter.all;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(AppStrings.billing),
        actions: [
          IconButton(
            tooltip: AppStrings.billingSettings,
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => openBillingSettings(context, ref),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: SizedBox(
                width: double.infinity,
                child: SegmentedButton<bool>(
                  showSelectedIcon: false,
                  segments: const [
                    ButtonSegment(value: false, label: Text(AppStrings.billingGrounds)),
                    ButtonSegment(value: true, label: Text(AppStrings.billingRecords)),
                  ],
                  selected: {_history},
                  onSelectionChanged: (s) => setState(() => _history = s.single),
                ),
              ),
            ),
            Expanded(
              child: _history
                  ? const _History()
                  : _Grounds(filter: _filter, onFilter: (f) => setState(() => _filter = f)),
            ),
          ],
        ),
      ),
    );
  }
}

/// Every ground, the soonest to end first, with what's due.
class _Grounds extends ConsumerWidget {
  final _Filter filter;
  final ValueChanged<_Filter> onFilter;

  const _Grounds({required this.filter, required this.onFilter});

  static bool _shows(_Filter filter, VenueSubscription s) => switch (filter) {
        _Filter.all => true,
        _Filter.toPay => s.canPayNextMonth(),
        _Filter.free => !s.canPayNextMonth() && s.kind != SubscriptionKind.paid,
        _Filter.paid => !s.canPayNextMonth() && s.kind == SubscriptionKind.paid,
      };

  static String _label(_Filter filter) => switch (filter) {
        _Filter.all => AppStrings.billingAll,
        _Filter.toPay => AppStrings.billingToPay,
        _Filter.free => AppStrings.billingFree,
        _Filter.paid => AppStrings.subscriptionKindLabel(SubscriptionKind.paid),
      };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final periods = ref.watch(allSubscriptionPeriodsProvider).valueOrNull;
    return AsyncView(
      value: ref.watch(allVenuesProvider),
      onRetry: () => ref.invalidate(allVenuesProvider),
      data: (venues) {
        // Grounds from before subscriptions have none until updates.sql runs.
        final subscribed = [
          for (final v in venues)
            if (v.subscription != null) v,
        ]..sort((a, b) => a.subscription!.endsAt.compareTo(b.subscription!.endsAt));
        final shown = [
          for (final v in subscribed)
            if (_shows(filter, v.subscription!)) v,
        ];
        return RefreshIndicator(
          onRefresh: () => Future.wait([
            ref.refresh(allVenuesProvider.future),
            ref.refresh(allSubscriptionPeriodsProvider.future),
          ]),
          child: venues.isEmpty
              ? ListView(
                  // Scrollable, so pull-to-refresh still works.
                  children: const [
                    SizedBox(height: 80),
                    EmptyState(icon: Icons.stadium_outlined, message: AppStrings.noVenuesAdded),
                  ],
                )
              : ListView(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
                  children: [
                    _Summary(
                      hidden: subscribed.where((v) => v.subscription!.isEnded()).length,
                      dueSoon: subscribed.where((v) => v.subscription!.endsSoon()).length,
                      received: periods == null ? null : SubscriptionPeriod.receivedInMonth(periods),
                    ),
                    const SizedBox(height: 14),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final f in _Filter.values)
                          ChoiceChip(
                            label: Text(AppStrings.withCount(
                                _label(f), subscribed.where((v) => _shows(f, v.subscription!)).length)),
                            selected: filter == f,
                            onSelected: (_) => onFilter(f),
                          ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    if (shown.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 24),
                        child: Text(AppStrings.noGroundsHere,
                            textAlign: TextAlign.center, style: TextStyle(color: AppColors.muted)),
                      ),
                    for (final venue in shown) ...[
                      _GroundCard(venue: venue, subscription: venue.subscription!),
                      const SizedBox(height: 10),
                    ],
                    const SizedBox(height: 6),
                    const InfoNote(icon: Icons.touch_app_outlined, text: AppStrings.billingHint),
                  ],
                ),
        );
      },
    );
  }
}

/// How many grounds are hidden and due soon, and what came in this month.
class _Summary extends StatelessWidget {
  final int hidden;
  final int dueSoon;
  final int? received; // null while the billing history loads

  const _Summary({required this.hidden, required this.dueSoon, required this.received});

  @override
  Widget build(BuildContext context) {
    final received = this.received;
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
        child: Row(
          children: [
            _Stat(value: '$hidden', label: AppStrings.billingHidden, color: AppColors.error),
            _Stat(value: '$dueSoon', label: AppStrings.billingDueSoon, color: AppColors.primaryDeep),
            _Stat(
              value: received == null ? '–' : PriceUtils.nu(received),
              label: AppStrings.receivedIn(BhutanTime.today()),
              color: AppColors.verified,
            ),
          ],
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final String value;
  final String label;
  final Color color;

  const _Stat({required this.value, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(value,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800, color: color)),
          ),
          const SizedBox(height: 2),
          Text(label,
              textAlign: TextAlign.center, style: const TextStyle(color: AppColors.muted, fontSize: 13, height: 1.3)),
        ],
      ),
    );
  }
}

/// A ground: its manager and fee, until when it's listed, and the next
/// payment once it's due. Tap for its Subscription page.
class _GroundCard extends StatelessWidget {
  final Venue venue;
  final VenueSubscription subscription;

  const _GroundCard({required this.venue, required this.subscription});

  @override
  Widget build(BuildContext context) {
    final s = subscription;
    final fee = s.feeNu;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push(Routes.venueSubscriptionFor(venue.id)),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(venue.name,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                  ),
                  const Icon(Icons.chevron_right_rounded, color: AppColors.muted),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                [
                  if (venue.managerName case final name? when name.trim().isNotEmpty) name,
                  fee == null ? '${AppStrings.monthlyFee}: ${AppStrings.feeNotSet}' : AppStrings.feePerMonth(fee),
                ].join(' · '),
                style: const TextStyle(color: AppColors.inkSoft),
              ),
              const SizedBox(height: 10),
              Align(alignment: Alignment.centerLeft, child: SubscriptionPill(subscription: s)),
              if (s.canPayNextMonth()) ...[
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilledButton.icon(
                    icon: const Icon(Icons.payments_outlined),
                    label: const Text(AppStrings.recordPayment),
                    onPressed: () => showRecordPaymentSheet(context, venue.id, s),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Every ground's free months, free time and payments, latest recorded
/// first. Tap one for its ground's Subscription page.
class _History extends ConsumerWidget {
  const _History();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final names = {for (final v in ref.watch(allVenuesProvider).valueOrNull ?? const <Venue>[]) v.id: v.name};
    return AsyncView(
      value: ref.watch(allSubscriptionPeriodsProvider),
      onRetry: () => ref.invalidate(allSubscriptionPeriodsProvider),
      data: (periods) => RefreshIndicator(
        onRefresh: () => ref.refresh(allSubscriptionPeriodsProvider.future),
        child: periods.isEmpty
            ? ListView(
                children: const [
                  SizedBox(height: 80),
                  EmptyState(icon: Icons.receipt_long_outlined, message: AppStrings.noBillingRecords),
                ],
              )
            : ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
                itemCount: periods.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, i) {
                  final p = periods[i];
                  return Card(
                    clipBehavior: Clip.antiAlias,
                    child: SubscriptionPeriodTile(
                      period: p,
                      venueName: names[p.venueId],
                      onTap: () => context.push(Routes.venueSubscriptionFor(p.venueId)),
                    ),
                  );
                },
              ),
      ),
    );
  }
}
