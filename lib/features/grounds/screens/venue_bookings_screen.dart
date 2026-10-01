import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show PostgrestException;

import '../../../core/constants/app_constants.dart';
import '../../../core/strings/app_strings.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/bhutan_time.dart';
import '../../../core/utils/error_messages.dart';
import '../../../core/utils/price_utils.dart';
import '../../../core/utils/text_utils.dart';
import '../../../shared/models/ground.dart';
import '../../../shared/models/ground_booking.dart';
import '../../../shared/widgets/async_view.dart';
import '../../../shared/widgets/confirm_dialog.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/form_error.dart';
import '../../../shared/widgets/icon_tile.dart';
import '../../../shared/widgets/info_note.dart';
import '../../../shared/widgets/primary_button.dart';
import '../../../shared/widgets/sheet_title.dart';
import '../../../shared/widgets/text_dialog.dart';
import '../data/booking_repository.dart';
import '../providers/booking_providers.dart';
import '../providers/venue_providers.dart';
import '../widgets/contact_row.dart';
import '../widgets/fact_row.dart';
import '../widgets/phone_booking_sheet.dart';
import '../widgets/status_pill.dart';

/// Bookings at a ground (its manager, and admins)
/// Purpose: Answer requests, follow what's coming, add bookings taken by
/// phone (everyone then sees the time as booked), and block time.
/// Backend: Reads ground_booking_list; set_booking_status, set_booking_paid,
/// book_by_phone, block_ground_time.
/// Done when: Each answer reaches the customer as a notification.
class VenueBookingsScreen extends ConsumerStatefulWidget {
  final String venueId;

  const VenueBookingsScreen({super.key, required this.venueId});

  @override
  ConsumerState<VenueBookingsScreen> createState() => _VenueBookingsScreenState();
}

class _VenueBookingsScreenState extends ConsumerState<VenueBookingsScreen> {
  // One of AppStrings.requests, upcoming, past.
  String _tab = AppStrings.requests;

  /// Which tab a booking goes under.
  static String _tabOf(GroundBooking b, DateTime now) {
    if (b.status == BookingStatus.pending && !b.hasStarted(now)) return AppStrings.requests;
    if (b.isUpcoming(now)) return AppStrings.upcoming;
    return AppStrings.past;
  }

  @override
  Widget build(BuildContext context) {
    final bookings = ref.watch(venueBookingsProvider(widget.venueId));
    final grounds = ref.watch(venueDetailsProvider(widget.venueId)).valueOrNull?.grounds ?? const <Ground>[];
    final waiting = ref.watch(waitingBookingCountProvider(widget.venueId));

    return Scaffold(
      appBar: AppBar(
        title: const Text(AppStrings.bookings),
        actions: [
          if (grounds.isNotEmpty)
            TextButton.icon(
              icon: const Icon(Icons.block_rounded),
              label: const Text(AppStrings.blockTime),
              onPressed: () => showModalBottomSheet<void>(
                context: context,
                showDragHandle: true,
                isScrollControlled: true,
                useSafeArea: true,
                builder: (_) => _BlockTimeSheet(venueId: widget.venueId, grounds: grounds),
              ),
            ),
        ],
      ),
      // Someone called: book one of the ground's times for them.
      floatingActionButton: grounds.isEmpty
          ? null
          : FloatingActionButton.extended(
              icon: const Icon(Icons.add_call),
              label: const Text(AppStrings.addBooking),
              onPressed: () => showModalBottomSheet<void>(
                context: context,
                showDragHandle: true,
                isScrollControlled: true,
                useSafeArea: true,
                builder: (_) => PhoneBookingSheet(venueId: widget.venueId, ground: grounds.first),
              ),
            ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: SizedBox(
                width: double.infinity,
                child: SegmentedButton<String>(
                  showSelectedIcon: false,
                  segments: [
                    ButtonSegment(
                      value: AppStrings.requests,
                      label: Text(waiting > 0 ? '${AppStrings.requests} ($waiting)' : AppStrings.requests),
                    ),
                    const ButtonSegment(value: AppStrings.upcoming, label: Text(AppStrings.upcoming)),
                    const ButtonSegment(value: AppStrings.past, label: Text(AppStrings.past)),
                  ],
                  selected: {_tab},
                  onSelectionChanged: (s) => setState(() => _tab = s.single),
                ),
              ),
            ),
            Expanded(
              child: AsyncView(
                value: bookings,
                onRetry: () => ref.invalidate(venueBookingsProvider(widget.venueId)),
                data: (bookings) {
                  final now = DateTime.now();
                  final shown = bookings.where((b) => _tabOf(b, now) == _tab).toList()
                    // What's next first; the past, latest first.
                    ..sort((a, b) => _tab == AppStrings.past
                        ? b.startsAt.compareTo(a.startsAt)
                        : a.startsAt.compareTo(b.startsAt));
                  return RefreshIndicator(
                    onRefresh: () => ref.refresh(venueBookingsProvider(widget.venueId).future),
                    child: shown.isEmpty
                        ? ListView(
                            // Scrollable, so pull-to-refresh still works.
                            children: [
                              const SizedBox(height: 80),
                              EmptyState(icon: Icons.event_note_outlined, message: AppStrings.noVenueBookings(_tab)),
                            ],
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
                            itemCount: shown.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 8),
                            itemBuilder: (context, i) => _OwnerBookingTile(booking: shown[i]),
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

String _whoFor(GroundBooking b) {
  if (b.isBlock) return AppStrings.blockedFor(b.ownerNote);
  final team = b.teamName?.trim() ?? '';
  return [AppStrings.bookedBy(b.contactName), if (team.isNotEmpty) team].join(' · ');
}

class _OwnerBookingTile extends StatelessWidget {
  final GroundBooking booking;

  const _OwnerBookingTile({required this.booking});

  @override
  Widget build(BuildContext context) {
    final muted = TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 13.5);
    final waiting = booking.status == BookingStatus.pending;
    return Card(
      color: waiting ? const Color(0xFFFFF8F1) : null,
      shape: waiting
          ? RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: BorderSide(color: AppColors.primary.withValues(alpha: 0.35)),
            )
          : null,
      child: ListTile(
        contentPadding: const EdgeInsets.fromLTRB(16, 10, 12, 10),
        leading: IconTile(
          icon: booking.isBlock ? Icons.block_rounded : Icons.sports_soccer_rounded,
          color: booking.isBlock ? AppColors.maroon : AppColors.primaryDeep,
          size: 48,
        ),
        title: Text(_whoFor(booking), style: const TextStyle(fontWeight: FontWeight.w700)),
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
                if (booking.isPhone) Text(AppStrings.byPhone, style: muted),
                if (!booking.isBlock)
                  Text('${PriceUtils.nu(booking.priceNu)} · ${AppStrings.paymentStatusLabel(booking.paymentStatus)}',
                      style: muted),
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
          builder: (_) => _OwnerBookingDetails(booking: booking),
        ),
      ),
    );
  }
}

/// Everything about one booking, and what the venue can do with it now.
class _OwnerBookingDetails extends ConsumerStatefulWidget {
  final GroundBooking booking;

  const _OwnerBookingDetails({required this.booking});

  @override
  ConsumerState<_OwnerBookingDetails> createState() => _OwnerBookingDetailsState();
}

class _OwnerBookingDetailsState extends ConsumerState<_OwnerBookingDetails> {
  bool _saving = false;

  /// [error]: what to say when [action] fails, if not the usual message.
  Future<void> _run(Future<void> Function(BookingRepository repo) action, String done,
      {String? Function(Object e)? error}) async {
    setState(() => _saving = true);
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final booking = widget.booking;
    try {
      await action(ref.read(bookingRepositoryProvider));
      ref.invalidate(venueBookingsProvider(booking.venueId));
      ref.invalidate(availabilityProvider((groundId: booking.groundId, day: BhutanTime.dayOf(booking.startsAt))));
      navigator.pop();
      messenger.hideCurrentSnackBar(); // the news now, not after the last message
      messenger.showSnackBar(SnackBar(content: Text(done)));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(error?.call(e) ?? ErrorMessages.from(e))));
      if (mounted) setState(() => _saving = false);
    }
  }

  /// Its day and time, held every week for the same person from now on.
  Future<void> _makeRegular() async {
    final booking = widget.booking;
    final time = booking.weeklyTime;
    final ok = await confirm(
      context,
      title: AppStrings.markRegularTitle,
      message: AppStrings.markRegularMessage(booking.contactName, time.weekday, time.startHour, time.endHour),
      confirmLabel: AppStrings.markRegular,
    );
    if (!ok || !mounted) return;
    await _run(
      (repo) async {
        await repo.makeRegular(booking.id);
        ref.invalidate(regularBookingsProvider(booking.groundId));
        ref.invalidate(bookingRecordsProvider(booking.venueId));
        ref.invalidate(availabilityProvider); // that day, every week
      },
      AppStrings.regularAdded(time.weekday, time.startHour, time.endHour),
      error: (e) => switch (e) {
        PostgrestException(code: '23P01') => AppStrings.regularClash,
        PostgrestException(code: '22023') => AppStrings.regularNotATime,
        _ => null,
      },
    );
  }

  /// Confirming, rejecting and cancelling ask for an optional message; the
  /// rest ask to confirm.
  Future<void> _setStatus(String status) async {
    final booking = widget.booking;
    String? note;
    if (booking.isBlock) {
      final ok = await confirm(context,
          title: AppStrings.removeBlockTitle, confirmLabel: AppStrings.removeBlock, destructive: true);
      if (!ok || !mounted) return;
      return _run((repo) => repo.setStatus(booking.id, status), AppStrings.blockRemoved);
    }
    // Taken by phone: nobody to send a message to in the app.
    if (booking.isPhone && status == BookingStatus.cancelled) {
      final ok = await confirm(context,
          title: AppStrings.cancelBookingTitle,
          message: AppStrings.cancelPhoneBookingMessage,
          confirmLabel: AppStrings.cancelBooking,
          destructive: true);
      if (!ok || !mounted) return;
      return _run((repo) => repo.setStatus(booking.id, status), AppStrings.phoneBookingCancelled);
    }
    switch (status) {
      case BookingStatus.confirmed || BookingStatus.rejected || BookingStatus.cancelled:
        note = await showTextDialog(
          context,
          title: switch (status) {
            BookingStatus.confirmed => AppStrings.confirmBookingTitle,
            BookingStatus.rejected => AppStrings.rejectBookingTitle,
            _ => AppStrings.cancelBookingTitle,
          },
          hint: switch (status) {
            BookingStatus.confirmed => AppStrings.confirmBookingHint,
            BookingStatus.rejected => AppStrings.rejectBookingHint,
            _ => AppStrings.cancelBookingVenueHint,
          },
          confirmLabel: switch (status) {
            BookingStatus.confirmed => AppStrings.confirmBooking,
            BookingStatus.rejected => AppStrings.rejectBooking,
            _ => AppStrings.cancelBooking,
          },
        );
        if (note == null) return;
      default:
        final ok = await confirm(
          context,
          title: status == BookingStatus.completed ? AppStrings.markPlayed : AppStrings.markNoShow,
          confirmLabel: status == BookingStatus.completed ? AppStrings.markPlayed : AppStrings.markNoShow,
        );
        if (!ok) return;
    }
    if (!mounted) return;
    await _run((repo) => repo.setStatus(booking.id, status, note: note),
        AppStrings.bookingStatusChanged(status, byOwner: true));
  }

  @override
  Widget build(BuildContext context) {
    final booking = widget.booking;
    final customerNote = booking.customerNote?.trim() ?? '';
    final ownerNote = booking.ownerNote?.trim() ?? '';
    // The regular booking holding its day and time every week, if any.
    final regulars = booking.isBlock ? null : ref.watch(regularBookingsProvider(booking.groundId)).valueOrNull;
    final regular = regulars?.where((r) => r.slot == booking.weeklyTime).firstOrNull;

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SheetTitle(_whoFor(booking)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                BookingStatusChip(booking: booking),
                if (booking.isPhone) Text(AppStrings.byPhone, style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
              ],
            ),
            const SizedBox(height: 16),
            FactRow(
              icon: Icons.schedule,
              label: AppStrings.whenLabel,
              value: AppStrings.bookingTime(booking.startsAt, booking.endsAt),
            ),
            if (!booking.isBlock) ...[
              FactRow(icon: Icons.payments_outlined, label: AppStrings.priceLabel, value: PriceUtils.nu(booking.priceNu)),
              FactRow(
                icon: Icons.account_balance_wallet_outlined,
                label: AppStrings.paymentTitle,
                value: [
                  AppStrings.paymentLabel(booking.paymentMethod),
                  AppStrings.paymentStatusLabel(booking.paymentStatus),
                  if (booking.paymentReference case final reference?) reference,
                ].join(' · '),
              ),
              if (booking.contactPhone case final phone?)
                FactRow(icon: Icons.phone_outlined, label: AppStrings.jobPhoneLabel, value: phone),
              if (booking.playersCount case final players?)
                FactRow(icon: Icons.groups_outlined, label: AppStrings.playersLabel, value: '$players'),
              if (regular != null)
                FactRow(
                  icon: Icons.event_repeat_rounded,
                  label: AppStrings.regularBooking,
                  value: [AppStrings.everyWeekday(regular.weekday, regular.startHour, regular.endHour), regular.name]
                      .join(' · '),
                ),
              if (customerNote.isNotEmpty) ...[
                const SizedBox(height: 4),
                MessageBox(title: AppStrings.messageFromCustomer, message: customerNote),
              ],
              if (ownerNote.isNotEmpty) ...[
                const SizedBox(height: 8),
                FactRow(icon: Icons.reply_rounded, label: AppStrings.yourMessage, value: ownerNote),
              ],
            ],
            const SizedBox(height: 16),
            if (_saving)
              const Center(child: CircularProgressIndicator())
            else
              ..._actions(booking, canMakeRegular: regulars != null && regular == null && booking.canBeMadeRegular),
          ],
        ),
      ),
    );
  }

  List<Widget> _actions(GroundBooking booking, {required bool canMakeRegular}) {
    const gap = SizedBox(height: 10);
    final outlined = OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(54));
    final phone = booking.contactPhone;
    final started = booking.hasStarted();

    if (booking.isBlock) {
      return [
        if (booking.isOpen && !booking.hasEnded())
          TextButton.icon(
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            icon: const Icon(Icons.delete_outline),
            label: const Text(AppStrings.removeBlock),
            onPressed: () => _setStatus(BookingStatus.cancelled),
          ),
      ];
    }
    return [
      // The venue calls or messages the customer about an open booking.
      if (booking.isOpen && phone != null) ...[
        ContactRow(phone: phone),
        gap,
      ],
      if (booking.status == BookingStatus.pending && !started) ...[
        FilledButton.icon(
          style: FilledButton.styleFrom(backgroundColor: AppColors.verified),
          icon: const Icon(Icons.check),
          label: const Text(AppStrings.confirmBooking),
          onPressed: () => _setStatus(BookingStatus.confirmed),
        ),
        gap,
        OutlinedButton.icon(
          style: outlined.copyWith(foregroundColor: const WidgetStatePropertyAll(AppColors.error)),
          icon: const Icon(Icons.close),
          label: const Text(AppStrings.rejectBooking),
          onPressed: () => _setStatus(BookingStatus.rejected),
        ),
        gap,
      ],
      if (booking.status == BookingStatus.confirmed && started) ...[
        FilledButton.icon(
          icon: const Icon(Icons.task_alt),
          label: const Text(AppStrings.markPlayed),
          onPressed: () => _setStatus(BookingStatus.completed),
        ),
        gap,
        OutlinedButton.icon(
          style: outlined,
          icon: const Icon(Icons.person_off_outlined),
          label: const Text(AppStrings.markNoShow),
          onPressed: () => _setStatus(BookingStatus.noShow),
        ),
        gap,
      ],
      if (booking.status != BookingStatus.pending && booking.status != BookingStatus.rejected &&
          booking.status != BookingStatus.cancelled) ...[
        OutlinedButton.icon(
          style: outlined,
          icon: Icon(booking.paymentStatus == PaymentStatus.paid ? Icons.money_off_outlined : Icons.paid_outlined),
          label: Text(booking.paymentStatus == PaymentStatus.paid ? AppStrings.markNotPaid : AppStrings.markPaid),
          onPressed: () {
            final paid = booking.paymentStatus != PaymentStatus.paid;
            _run((repo) => repo.setPaid(booking.id, paid), AppStrings.paymentChanged(paid: paid));
          },
        ),
        gap,
      ],
      // They play at this time every week: hold it for them.
      if (canMakeRegular) ...[
        OutlinedButton.icon(
          style: outlined,
          icon: const Icon(Icons.event_repeat_rounded),
          label: const Text(AppStrings.markRegular),
          onPressed: _makeRegular,
        ),
        gap,
      ],
      if (booking.status == BookingStatus.confirmed && !started)
        TextButton.icon(
          style: TextButton.styleFrom(foregroundColor: AppColors.error),
          icon: const Icon(Icons.cancel_outlined),
          label: const Text(AppStrings.cancelBooking),
          onPressed: () => _setStatus(BookingStatus.cancelled),
        ),
    ];
  }
}

/// The manager blocks time on the ground, on one day.
class _BlockTimeSheet extends ConsumerStatefulWidget {
  final String venueId;
  final List<Ground> grounds;

  const _BlockTimeSheet({required this.venueId, required this.grounds});

  @override
  ConsumerState<_BlockTimeSheet> createState() => _BlockTimeSheetState();
}

class _BlockTimeSheetState extends ConsumerState<_BlockTimeSheet> {
  late final String _groundId = widget.grounds.first.id;
  DateTime _day = BhutanTime.today();
  // The next whole hour today; 6 am on other days.
  late int _from = _firstHour(_day);
  late int _until = _from + 1;
  final _reason = TextEditingController();
  bool _saving = false;
  String? _error;

  static int _firstHour(DateTime day) {
    if (day != BhutanTime.today()) return 6;
    return (BhutanTime.of(DateTime.now()).hour + 1).clamp(0, 23);
  }

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  Future<void> _pickDay() async {
    DateTime local(DateTime day) => DateTime(day.year, day.month, day.day);
    final today = BhutanTime.today();
    final picked = await showDatePicker(
      context: context,
      initialDate: local(_day),
      firstDate: local(today),
      lastDate: local(today.add(const Duration(days: AppConstants.blockDaysAhead))),
    );
    if (picked == null) return;
    setState(() {
      _day = DateTime.utc(picked.year, picked.month, picked.day);
      _from = _firstHour(_day);
      _until = _from + 1;
    });
  }

  Future<void> _block() async {
    if (_saving) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    try {
      await ref.read(bookingRepositoryProvider).blockTime(
            groundId: _groundId,
            start: BhutanTime.at(_day, _from),
            end: BhutanTime.at(_day, _until),
            reason: _reason.text.orNull,
          );
      ref.invalidate(venueBookingsProvider(widget.venueId));
      ref.invalidate(availabilityProvider((groundId: _groundId, day: _day)));
      navigator.pop();
      messenger.showSnackBar(const SnackBar(content: Text(AppStrings.timeBlocked)));
    } catch (e) {
      if (mounted) {
        setState(() => _error = switch (e) {
              PostgrestException(code: '23P01') => AppStrings.blockOverlaps,
              PostgrestException(code: '22023') => AppStrings.timeNotBookable,
              _ => ErrorMessages.from(e),
            });
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {

    DropdownButtonFormField<int> hourField(String label, int value, Iterable<int> hours, ValueChanged<int> onChanged) =>
        DropdownButtonFormField<int>(
          initialValue: value,
          icon: const Icon(Icons.keyboard_arrow_down_rounded),
          borderRadius: BorderRadius.circular(16),
          dropdownColor: Colors.white,
          menuMaxHeight: 400,
          decoration: InputDecoration(labelText: label),
          items: [for (final h in hours) DropdownMenuItem(value: h, child: Text(AppStrings.hourLabel(h)))],
          onChanged: (h) {
            if (h != null) onChanged(h);
          },
        );

    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(24, 0, 24, 16 + MediaQuery.viewInsetsOf(context).bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SheetTitle(AppStrings.blockTime),
            const SizedBox(height: 8),
            const InfoNote(icon: Icons.block_rounded, iconColor: AppColors.maroon, text: AppStrings.blockTimeHint),
            const SizedBox(height: 16),
            Card(
              child: ListTile(
                leading: const IconTile(icon: Icons.calendar_month_outlined),
                title: Text(AppStrings.dayLabel(_day)),
                subtitle: const Text(AppStrings.blockDay),
                trailing: const Icon(Icons.chevron_right_rounded, color: AppColors.muted),
                onTap: _pickDay,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: hourField(AppStrings.blockFrom, _from, [for (var h = 0; h < 24; h++) h], (h) {
                    setState(() {
                      _from = h;
                      if (_until <= h) _until = h + 1;
                    });
                  }),
                ),
                const SizedBox(width: 12),
                Expanded(
                  // Keyed by the start, so it resets when that moves past it.
                  child: KeyedSubtree(
                    key: ValueKey(_from),
                    child: hourField(AppStrings.blockUntil, _until, [for (var h = _from + 1; h <= 24; h++) h],
                        (h) => setState(() => _until = h)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _reason,
              maxLength: 500,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(labelText: AppStrings.blockReason, hintText: AppStrings.blockReasonHint),
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              FormError(_error!),
            ],
            const SizedBox(height: 16),
            PrimaryButton(label: AppStrings.blockTime, isLoading: _saving, onPressed: _block),
          ],
        ),
      ),
    );
  }
}
