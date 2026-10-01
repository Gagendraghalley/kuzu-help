import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/router/route_names.dart';
import '../../../core/strings/app_strings.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/error_messages.dart';
import '../../../core/utils/launcher_utils.dart';
import '../../../core/utils/price_utils.dart';
import '../../../shared/models/ground_booking.dart';
import '../../../shared/widgets/async_view.dart';
import '../../../shared/widgets/confirm_dialog.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/icon_tile.dart';
import '../../../shared/widgets/text_dialog.dart';
import '../data/booking_repository.dart';
import '../providers/booking_providers.dart';
import '../widgets/fact_row.dart';
import '../widgets/status_pill.dart';

/// My bookings
/// Purpose: Customers follow their ground bookings: waiting, confirmed, played.
/// Backend: Reads ground_booking_list; cancels with set_booking_status; adds
/// a payment's journal number with set_booking_payment_ref.
/// Done when: Cancelling tells the venue, and a played booking can be reviewed.
class MyBookingsScreen extends ConsumerStatefulWidget {
  const MyBookingsScreen({super.key});

  @override
  ConsumerState<MyBookingsScreen> createState() => _MyBookingsScreenState();
}

class _MyBookingsScreenState extends ConsumerState<MyBookingsScreen> {
  bool _showUpcoming = true;

  @override
  Widget build(BuildContext context) {
    final bookings = ref.watch(myBookingsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text(AppStrings.myBookings)),
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
                    ButtonSegment(value: true, label: Text(AppStrings.upcoming)),
                    ButtonSegment(value: false, label: Text(AppStrings.past)),
                  ],
                  selected: {_showUpcoming},
                  onSelectionChanged: (s) => setState(() => _showUpcoming = s.single),
                ),
              ),
            ),
            Expanded(
              child: AsyncView(
                value: bookings,
                onRetry: () => ref.invalidate(myBookingsProvider),
                data: (bookings) {
                  final now = DateTime.now();
                  final shown = bookings.where((b) => b.isUpcoming(now) == _showUpcoming).toList();
                  // Upcoming: soonest first. Past: latest first, as they come.
                  if (_showUpcoming) shown.sort((a, b) => a.startsAt.compareTo(b.startsAt));
                  return RefreshIndicator(
                    onRefresh: () => ref.refresh(myBookingsProvider.future),
                    child: shown.isEmpty
                        ? ListView(
                            // Scrollable, so pull-to-refresh still works.
                            children: [
                              const SizedBox(height: 80),
                              EmptyState(
                                icon: Icons.event_available_rounded,
                                message: AppStrings.noBookings(upcoming: _showUpcoming),
                              ),
                            ],
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                            itemCount: shown.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 8),
                            itemBuilder: (context, i) => _BookingTile(booking: shown[i]),
                          ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BookingTile extends StatelessWidget {
  final GroundBooking booking;

  const _BookingTile({required this.booking});

  @override
  Widget build(BuildContext context) {
    final muted = TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 13.5);
    return Card(
      child: ListTile(
        contentPadding: const EdgeInsets.fromLTRB(16, 10, 12, 10),
        leading: const IconTile(icon: Icons.sports_soccer_rounded, size: 48),
        title: Text(booking.venueName, style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 2),
            Text(AppStrings.bookingTime(booking.startsAt, booking.endsAt),
                style: const TextStyle(color: AppColors.inkSoft)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                BookingStatusChip(booking: booking),
                Text(PriceUtils.nu(booking.priceNu), style: muted),
              ],
            ),
          ],
        ),
        trailing: const Icon(Icons.chevron_right_rounded, color: AppColors.muted),
        onTap: () => showModalBottomSheet<void>(
          context: context,
          showDragHandle: true,
          isScrollControlled: true,
          useSafeArea: true,
          builder: (_) => _BookingDetails(booking: booking),
        ),
      ),
    );
  }
}

/// Everything about one booking, and what the customer can do with it now.
class _BookingDetails extends ConsumerStatefulWidget {
  final GroundBooking booking;

  const _BookingDetails({required this.booking});

  @override
  ConsumerState<_BookingDetails> createState() => _BookingDetailsState();
}

class _BookingDetailsState extends ConsumerState<_BookingDetails> {
  bool _saving = false;

  /// Runs [action], then closes the sheet with [done], or shows the error.
  Future<void> _run(Future<void> Function(BookingRepository repo) action, String done) async {
    setState(() => _saving = true);
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    try {
      await action(ref.read(bookingRepositoryProvider));
      ref.invalidate(myBookingsProvider);
      navigator.pop();
      messenger.showSnackBar(SnackBar(content: Text(done)));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(ErrorMessages.from(e))));
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _cancel() async {
    final booking = widget.booking;
    final ok = await confirm(
      context,
      title: AppStrings.cancelBookingTitle,
      message: booking.isLateToCancel() ? AppStrings.lateCancelWarning(booking.freeCancelHours) : null,
      confirmLabel: AppStrings.cancelBooking,
      destructive: true,
    );
    if (!ok || !mounted) return;
    await _run((repo) => repo.setStatus(booking.id, BookingStatus.cancelled),
        AppStrings.bookingStatusChanged(BookingStatus.cancelled));
  }

  Future<void> _addJournalNumber() async {
    final booking = widget.booking;
    final reference = await showTextDialog(
      context,
      title: AppStrings.journalNumberTitle,
      hint: AppStrings.journalNumberHint,
      confirmLabel: AppStrings.save,
      initialText: booking.paymentReference,
      requiredMessage: AppStrings.enterJournalNumber,
      maxLength: 60,
    );
    if (reference == null || !mounted) return;
    await _run((repo) => repo.setPaymentRef(booking.id, reference), AppStrings.journalNumberSaved);
  }

  @override
  Widget build(BuildContext context) {
    final booking = widget.booking;
    final text = Theme.of(context).textTheme;
    final ownerNote = booking.ownerNote?.trim() ?? '';
    final reference = booking.paymentReference;

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(booking.venueName, style: text.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [BookingStatusChip(booking: booking)],
            ),
            const SizedBox(height: 16),
            FactRow(
              icon: Icons.schedule,
              label: AppStrings.whenLabel,
              value: AppStrings.bookingTime(booking.startsAt, booking.endsAt),
            ),
            FactRow(icon: Icons.location_on_outlined, label: AppStrings.whereLabel, value: booking.venueLocation),
            FactRow(icon: Icons.payments_outlined, label: AppStrings.priceLabel, value: PriceUtils.nu(booking.priceNu)),
            FactRow(
              icon: Icons.account_balance_wallet_outlined,
              label: AppStrings.paymentTitle,
              value: [
                AppStrings.paymentLabel(booking.paymentMethod),
                AppStrings.paymentStatusLabel(booking.paymentStatus),
                if (reference != null) reference,
              ].join(' · '),
            ),
            if (booking.teamName case final team?) FactRow(icon: Icons.groups_outlined, label: AppStrings.teamLabel, value: team),
            if (booking.playersCount case final players?)
              FactRow(icon: Icons.person_outline, label: AppStrings.playersLabel, value: '$players'),
            if (booking.customerNote case final note?) FactRow(icon: Icons.notes, label: AppStrings.noteLabel, value: note),
            if (ownerNote.isNotEmpty) ...[
              const SizedBox(height: 8),
              MessageBox(title: AppStrings.messageFromVenue, message: ownerNote),
            ],
            const SizedBox(height: 16),
            if (_saving) const Center(child: CircularProgressIndicator()) else ..._actions(booking),
          ],
        ),
      ),
    );
  }

  List<Widget> _actions(GroundBooking booking) {
    const gap = SizedBox(height: 10);
    final outlined = OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(54));
    final whatsapp = booking.venueWhatsapp;
    return [
      if (booking.isUpcoming()) ...[
        Row(
          children: [
            Expanded(
              child: FilledButton.icon(
                icon: const Icon(Icons.call),
                label: const Text(AppStrings.call),
                onPressed: () => LauncherUtils.call(booking.venuePhone),
              ),
            ),
            if (whatsapp != null) ...[
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(backgroundColor: AppColors.whatsapp),
                  icon: const Icon(Icons.chat),
                  label: const Text(AppStrings.whatsapp),
                  onPressed: () => LauncherUtils.whatsapp(whatsapp),
                ),
              ),
            ],
          ],
        ),
        gap,
      ],
      if (booking.isOpen && booking.paidAdvanceByTransfer && booking.paymentStatus != PaymentStatus.paid) ...[
        OutlinedButton.icon(
          style: outlined,
          icon: const Icon(Icons.receipt_long_outlined),
          label: const Text(AppStrings.addJournalNumber),
          onPressed: _addJournalNumber,
        ),
        gap,
      ],
      if (booking.canBeReviewed) ...[
        FilledButton.icon(
          icon: const Icon(Icons.rate_review_outlined),
          label: const Text(AppStrings.writeReview),
          onPressed: () {
            Navigator.pop(context);
            context.push(Routes.writeVenueReviewFor(booking.venueId));
          },
        ),
        gap,
      ],
      OutlinedButton.icon(
        style: outlined,
        icon: const Icon(Icons.storefront_outlined),
        label: const Text(AppStrings.openVenuePage),
        onPressed: () {
          Navigator.pop(context);
          context.push(Routes.venueDetailsFor(booking.venueId));
        },
      ),
      if (booking.isOpen && !booking.hasStarted()) ...[
        gap,
        TextButton.icon(
          style: TextButton.styleFrom(foregroundColor: AppColors.error),
          icon: const Icon(Icons.cancel_outlined),
          label: const Text(AppStrings.cancelBooking),
          onPressed: _cancel,
        ),
      ],
    ];
  }
}
