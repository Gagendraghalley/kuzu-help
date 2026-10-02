import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/strings/app_strings.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/bhutan_time.dart';
import '../../../core/utils/error_messages.dart';
import '../../../core/utils/price_utils.dart';
import '../../../core/utils/text_utils.dart';
import '../../../shared/models/subscription.dart';
import '../../../shared/models/venue.dart';
import '../../../shared/widgets/async_view.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/form_error.dart';
import '../../../shared/widgets/icon_tile.dart';
import '../../../shared/widgets/info_note.dart';
import '../../../shared/widgets/primary_button.dart';
import '../../../shared/widgets/section_header.dart';
import '../../../shared/widgets/sheet_title.dart';
import '../../admin/providers/admin_providers.dart';
import '../data/subscription_repository.dart';
import '../providers/subscription_providers.dart';
import '../providers/venue_providers.dart';
import '../widgets/fact_row.dart';
import '../widgets/status_pill.dart';

/// A ground's subscription: its manager's (to read) and admins'
/// Purpose: How long players can find and book the ground, its monthly fee,
/// how to pay, and its billing history. Admins record each month's payment
/// (one month at a time), give free time and set the fee.
/// Backend: The venues row (venueDetailsProvider), venue_subscription_periods
/// and subscription_settings; record_subscription_payment,
/// extend_free_period and set_subscription_fee (admins only).
/// Done when: The manager knows when to pay and how; an admin records a
/// payment in a few taps.
class SubscriptionScreen extends ConsumerWidget {
  final String venueId;

  const SubscriptionScreen({super.key, required this.venueId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text(AppStrings.subscription)),
      body: SafeArea(
        child: AsyncView(
          value: ref.watch(venueDetailsProvider(venueId)),
          onRetry: () => ref.invalidate(venueDetailsProvider(venueId)),
          data: (details) {
            final venue = details?.venue;
            final subscription = venue?.subscription;
            if (venue == null) {
              return const EmptyState(icon: Icons.receipt_long_outlined, message: AppStrings.venueNotListed);
            }
            if (subscription == null) {
              return const EmptyState(icon: Icons.receipt_long_outlined, message: AppStrings.databaseUpdateNeeded);
            }
            return RefreshIndicator(
              onRefresh: () => Future.wait([
                ref.refresh(venueDetailsProvider(venueId).future),
                ref.refresh(subscriptionPeriodsProvider(venueId).future),
                ref.refresh(subscriptionSettingsProvider.future),
              ]),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
                children: [
                  _StatusCard(venue: venue, subscription: subscription),
                  const SizedBox(height: 12),
                  if (ref.watch(isAdminProvider))
                    _AdminCard(venue: venue, subscription: subscription)
                  else
                    const InfoNote(icon: Icons.verified_user_outlined, text: AppStrings.subscriptionManagerNote),
                  const SizedBox(height: 28),
                  const SectionHeader(AppStrings.howToPaySubscription),
                  const SizedBox(height: 10),
                  const _HowToPay(),
                  const SizedBox(height: 28),
                  const SectionHeader(AppStrings.billingHistory),
                  const SizedBox(height: 10),
                  _History(venueId: venue.id),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

/// Where the subscription stands: until when, the fee, and what to do in its
/// last days or once it has ended.
class _StatusCard extends StatelessWidget {
  final Venue venue;
  final VenueSubscription subscription;

  const _StatusCard({required this.venue, required this.subscription});

  @override
  Widget build(BuildContext context) {
    final s = subscription;
    final fee = s.feeNu;
    final ended = s.isEnded();
    final text = Theme.of(context).textTheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const IconTile(icon: Icons.receipt_long_outlined, size: 44),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(venue.name, style: text.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                      const SizedBox(height: 4),
                      SubscriptionPill(subscription: s),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(ended ? AppStrings.endedOn(s.lastDay) : AppStrings.listedUntil(s.lastDay),
                style: const TextStyle(color: AppColors.inkSoft, height: 1.4)),
            const SizedBox(height: 8),
            FactRow(
              icon: Icons.payments_outlined,
              label: AppStrings.monthlyFee,
              value: fee == null ? AppStrings.feeNotSet : AppStrings.feePerMonth(fee),
            ),
            if (ended || s.endsSoon()) ...[
              const SizedBox(height: 12),
              InfoNote(
                icon: ended ? Icons.visibility_off_outlined : Icons.event_busy_outlined,
                iconColor: ended ? AppColors.error : AppColors.primaryDeep,
                text: ended ? AppStrings.payToListAgain(fee) : AppStrings.payNextMonth(fee),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Admins only: record the next month's payment (from the last 7 days, one
/// month at a time), give free time, change the fee.
class _AdminCard extends StatelessWidget {
  final Venue venue;
  final VenueSubscription subscription;

  const _AdminCard({required this.venue, required this.subscription});

  Future<void> _open(BuildContext context, Widget sheet) => showModalBottomSheet<void>(
        context: context,
        showDragHandle: true,
        isScrollControlled: true,
        useSafeArea: true,
        builder: (_) => sheet,
      );

  @override
  Widget build(BuildContext context) {
    final s = subscription;
    final canPay = s.canPayNextMonth();
    return Card(
      color: const Color(0xFFFFF8F1),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: AppColors.primary.withValues(alpha: 0.35)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            FilledButton.icon(
              icon: const Icon(Icons.payments_outlined),
              label: const Text(AppStrings.recordPayment),
              onPressed: canPay ? () => _open(context, _PaymentSheet(venueId: venue.id, subscription: s)) : null,
            ),
            if (!canPay) ...[
              const SizedBox(height: 8),
              Text(AppStrings.nextPaymentFrom(s.lastDay, s.payableFrom),
                  style: const TextStyle(color: AppColors.inkSoft, height: 1.4)),
            ],
            const SizedBox(height: 10),
            OutlinedButton.icon(
              icon: const Icon(Icons.card_giftcard_outlined),
              label: const Text(AppStrings.giveFreeTime),
              onPressed: () => _open(context, _FreeTimeSheet(venueId: venue.id, subscription: s)),
            ),
            const SizedBox(height: 4),
            TextButton.icon(
              icon: const Icon(Icons.edit_outlined),
              label: const Text(AppStrings.changeFee),
              onPressed: () => _open(context, _FeeSheet(venueId: venue.id, fee: s.feeNu)),
            ),
          ],
        ),
      ),
    );
  }
}

/// How managers pay Kuzu Help, as admins wrote it under Billing settings.
class _HowToPay extends ConsumerWidget {
  const _HowToPay();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return switch (ref.watch(subscriptionSettingsProvider)) {
      AsyncData(value: SubscriptionSettings(paymentInfo: final info?)) when info.trim().isNotEmpty => Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: SelectableText(info, style: const TextStyle(color: AppColors.ink, height: 1.45)),
          ),
        ),
      AsyncData() => const InfoNote(icon: Icons.info_outline_rounded, text: AppStrings.howToPayNotSet),
      AsyncError() => Card(
          child: ListTile(
            title: const Text(AppStrings.genericError),
            trailing: TextButton(
              onPressed: () => ref.invalidate(subscriptionSettingsProvider),
              child: const Text(AppStrings.retry),
            ),
          ),
        ),
      _ => const Padding(padding: EdgeInsets.all(16), child: Center(child: CircularProgressIndicator())),
    };
  }
}

/// Every period the ground has had, latest first: free months, free time
/// and payments, with how each was paid.
class _History extends ConsumerWidget {
  final String venueId;

  const _History({required this.venueId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final muted = TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant);
    return switch (ref.watch(subscriptionPeriodsProvider(venueId))) {
      AsyncData(value: final periods) when periods.isNotEmpty => Card(
          child: Column(
            children: [
              for (final (i, p) in periods.indexed) ...[
                if (i > 0) const Divider(indent: 70, endIndent: 16),
                ListTile(
                  leading: IconTile(
                    icon: p.kind == SubscriptionKind.paid ? Icons.payments_outlined : Icons.card_giftcard_outlined,
                    color: p.kind == SubscriptionKind.paid ? AppColors.verified : AppColors.primaryDeep,
                  ),
                  title: Text(
                    [AppStrings.subscriptionKindLabel(p.kind), if (p.amountNu case final amount?) PriceUtils.nu(amount)]
                        .join(' · '),
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  subtitle: Text([
                    AppStrings.periodDates(p.firstDay, p.lastDay),
                    [
                      if (p.paymentMethod case final method?) AppStrings.billingMethodLabel(method),
                      if (p.paymentReference case final reference?) AppStrings.journalNo(reference),
                      if (p.note case final note?) note,
                    ].join(' · '),
                  ].where((line) => line.isNotEmpty).join('\n')),
                ),
              ],
            ],
          ),
        ),
      AsyncData() => Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Text(AppStrings.noBillingHistory, style: muted),
        ),
      AsyncError() => Card(
          child: ListTile(
            title: const Text(AppStrings.genericError),
            trailing: TextButton(
              onPressed: () => ref.invalidate(subscriptionPeriodsProvider(venueId)),
              child: const Text(AppStrings.retry),
            ),
          ),
        ),
      _ => const Padding(padding: EdgeInsets.all(16), child: Center(child: CircularProgressIndicator())),
    };
  }
}

/// After an admin changes a subscription: everything that shows it.
void _refreshSubscription(WidgetRef ref, String venueId) {
  ref.invalidate(venueDetailsProvider(venueId));
  ref.invalidate(subscriptionPeriodsProvider(venueId));
  ref.invalidate(allVenuesProvider);
  ref.invalidate(myVenuesProvider);
}

/// A whole number of Ngultrum, 1 to 1,000,000, as the database takes it.
int? _amountOf(String text) => switch (int.tryParse(text.trim())) {
      final n? when n >= 1 && n <= 1000000 => n,
      _ => null,
    };

TextFormField _amountField(TextEditingController controller, String label) => TextFormField(
      controller: controller,
      keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      decoration: InputDecoration(labelText: label, prefixText: '${PriceUtils.currency} '),
      validator: (v) => _amountOf(v ?? '') == null ? AppStrings.enterAmount : null,
    );

/// Admins: the next month, paid. Always exactly one month, from where the
/// subscription ends (or today, once it has ended).
class _PaymentSheet extends ConsumerStatefulWidget {
  final String venueId;
  final VenueSubscription subscription;

  const _PaymentSheet({required this.venueId, required this.subscription});

  @override
  ConsumerState<_PaymentSheet> createState() => _PaymentSheetState();
}

class _PaymentSheetState extends ConsumerState<_PaymentSheet> {
  final _formKey = GlobalKey<FormState>();
  late final _amount = TextEditingController(text: widget.subscription.feeNu?.toString() ?? '');
  final _reference = TextEditingController();
  final _note = TextEditingController();
  String _method = BillingMethod.mbob;
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _amount.dispose();
    _reference.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving || !_formKey.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    try {
      await ref.read(subscriptionRepositoryProvider).recordPayment(
            widget.venueId,
            amountNu: _amountOf(_amount.text)!,
            method: _method,
            reference: _reference.text.orNull,
            note: _note.text.orNull,
          );
      _refreshSubscription(ref, widget.venueId);
      navigator.pop();
      messenger.showSnackBar(const SnackBar(content: Text(AppStrings.paymentRecorded)));
    } catch (e) {
      if (mounted) setState(() => _error = ErrorMessages.from(e));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final month = widget.subscription.next(months: 1);
    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(24, 0, 24, 16 + MediaQuery.viewInsetsOf(context).bottom),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SheetTitle(AppStrings.recordPayment),
              const SizedBox(height: 8),
              InfoNote(
                icon: Icons.event_available_outlined,
                iconColor: AppColors.verified,
                text: AppStrings.coversMonth(
                    BhutanTime.dayOf(month.start), VenueSubscription.lastDayBefore(month.end)),
              ),
              const SizedBox(height: 16),
              _amountField(_amount, AppStrings.amountPaid),
              const SizedBox(height: 16),
              Text(AppStrings.paidBy, style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final method in BillingMethod.all)
                    ChoiceChip(
                      label: Text(AppStrings.billingMethodLabel(method)),
                      selected: _method == method,
                      onSelected: (_) => setState(() => _method = method),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _reference,
                maxLength: 60,
                decoration: const InputDecoration(labelText: AppStrings.journalNumberOptional),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _note,
                maxLength: 300,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(labelText: AppStrings.billingNote, hintText: AppStrings.billingNoteHint),
              ),
              if (_error != null) ...[
                const SizedBox(height: 8),
                FormError(_error!),
              ],
              const SizedBox(height: 16),
              PrimaryButton(label: AppStrings.savePayment, isLoading: _saving, onPressed: _save),
            ],
          ),
        ),
      ),
    );
  }
}

/// Admins: free time, as long as they like, after what the ground has now.
class _FreeTimeSheet extends ConsumerStatefulWidget {
  final String venueId;
  final VenueSubscription subscription;

  const _FreeTimeSheet({required this.venueId, required this.subscription});

  @override
  ConsumerState<_FreeTimeSheet> createState() => _FreeTimeSheetState();
}

class _FreeTimeSheetState extends ConsumerState<_FreeTimeSheet> {
  // (months, days)
  static const _lengths = [(0, 7), (0, 14), (1, 0), (2, 0), (3, 0), (6, 0), (12, 0)];

  final _note = TextEditingController();
  var _length = (1, 0);
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final (months, days) = _length;
    try {
      await ref
          .read(subscriptionRepositoryProvider)
          .extendFreePeriod(widget.venueId, months: months, days: days, note: _note.text.orNull);
      _refreshSubscription(ref, widget.venueId);
      navigator.pop();
      messenger.showSnackBar(const SnackBar(content: Text(AppStrings.freeTimeGiven)));
    } catch (e) {
      if (mounted) setState(() => _error = ErrorMessages.from(e));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final (months, days) = _length;
    final until = widget.subscription.next(months: months, days: days).end;
    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(24, 0, 24, 16 + MediaQuery.viewInsetsOf(context).bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SheetTitle(AppStrings.giveFreeTime),
            const SizedBox(height: 8),
            const InfoNote(icon: Icons.card_giftcard_outlined, text: AppStrings.freeTimeHint),
            const SizedBox(height: 16),
            Text(AppStrings.howLong, style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final length in _lengths)
                  ChoiceChip(
                    label: Text(AppStrings.freeLength(length.$1, length.$2)),
                    selected: _length == length,
                    onSelected: (_) => setState(() => _length = length),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Text(AppStrings.freeUntil(VenueSubscription.lastDayBefore(until)),
                style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.verified)),
            const SizedBox(height: 16),
            TextField(
              controller: _note,
              maxLength: 300,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(labelText: AppStrings.billingNote),
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              FormError(_error!),
            ],
            const SizedBox(height: 16),
            PrimaryButton(label: AppStrings.giveLengthFree(months, days), isLoading: _saving, onPressed: _save),
          ],
        ),
      ),
    );
  }
}

/// Admins: the ground's monthly fee.
class _FeeSheet extends ConsumerStatefulWidget {
  final String venueId;
  final int? fee;

  const _FeeSheet({required this.venueId, required this.fee});

  @override
  ConsumerState<_FeeSheet> createState() => _FeeSheetState();
}

class _FeeSheetState extends ConsumerState<_FeeSheet> {
  final _formKey = GlobalKey<FormState>();
  late final _fee = TextEditingController(text: widget.fee?.toString() ?? '');
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _fee.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving || !_formKey.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    try {
      await ref.read(subscriptionRepositoryProvider).setFee(widget.venueId, _amountOf(_fee.text));
      _refreshSubscription(ref, widget.venueId);
      navigator.pop();
      messenger.showSnackBar(const SnackBar(content: Text(AppStrings.feeSaved)));
    } catch (e) {
      if (mounted) setState(() => _error = ErrorMessages.from(e));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(24, 0, 24, 16 + MediaQuery.viewInsetsOf(context).bottom),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SheetTitle(AppStrings.changeFee),
              const SizedBox(height: 8),
              const InfoNote(icon: Icons.payments_outlined, text: AppStrings.feeHint),
              const SizedBox(height: 16),
              _amountField(_fee, AppStrings.monthlyFee),
              if (_error != null) ...[
                const SizedBox(height: 8),
                FormError(_error!),
              ],
              const SizedBox(height: 16),
              PrimaryButton(label: AppStrings.save, isLoading: _saving, onPressed: _save),
            ],
          ),
        ),
      ),
    );
  }
}
