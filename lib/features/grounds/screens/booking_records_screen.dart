import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/strings/app_strings.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/price_utils.dart';
import '../../../shared/models/regular_booking.dart';
import '../../../shared/widgets/async_view.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/icon_tile.dart';
import '../../../shared/widgets/info_note.dart';
import '../../../shared/widgets/sheet_title.dart';
import '../providers/booking_providers.dart';
import '../widgets/contact_row.dart';
import '../widgets/status_pill.dart';

/// Booking records (a ground's manager, and admins)
/// Purpose: Everyone who has booked the ground, in the app, by phone or every
/// week, for future reference: how often, when last, and how to reach them.
/// Backend: Reads ground_booking_list (all of it, not only the last 30 days)
/// and ground_regular_bookings.
/// Done when: The manager finds someone who booked before and calls them.
class BookingRecordsScreen extends ConsumerWidget {
  final String venueId;

  const BookingRecordsScreen({super.key, required this.venueId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text(AppStrings.bookingRecords)),
      body: SafeArea(
        child: AsyncView(
          value: ref.watch(bookingRecordsProvider(venueId)),
          onRetry: () => ref.invalidate(bookingRecordsProvider(venueId)),
          data: (records) => RefreshIndicator(
            onRefresh: () => ref.refresh(bookingRecordsProvider(venueId).future),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
              children: [
                const InfoNote(icon: Icons.people_alt_outlined, text: AppStrings.bookingRecordsHint),
                const SizedBox(height: 12),
                if (records.isEmpty)
                  const Padding(
                    padding: EdgeInsets.only(top: 48),
                    child: EmptyState(icon: Icons.people_alt_outlined, message: AppStrings.noBookingRecords),
                  )
                else
                  for (final record in records) ...[
                    _RecordTile(record: record),
                    const SizedBox(height: 8),
                  ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RecordTile extends StatelessWidget {
  final BookerRecord record;

  const _RecordTile({required this.record});

  @override
  Widget build(BuildContext context) {
    final last = record.lastBooked;
    return Card(
      child: ListTile(
        contentPadding: const EdgeInsets.fromLTRB(16, 8, 12, 8),
        leading: const IconTile(icon: Icons.person_outline, size: 44),
        title: Text(record.name, style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Text([
          if (record.phone case final phone?) phone,
          if (record.bookings.isNotEmpty) AppStrings.timesBooked(record.bookings.length),
          if (last != null) AppStrings.lastBooked(last),
        ].join(' · ')),
        trailing: record.isRegular ? const StatusPill(label: AppStrings.regular, color: AppColors.verified) : null,
        onTap: () => showModalBottomSheet<void>(
          context: context,
          showDragHandle: true,
          isScrollControlled: true,
          useSafeArea: true,
          builder: (_) => _RecordSheet(record: record),
        ),
      ),
    );
  }
}

/// One person: how to reach them, their regular times and every booking.
class _RecordSheet extends StatelessWidget {
  final BookerRecord record;

  const _RecordSheet({required this.record});

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final muted = TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant);
    final phone = record.phone;
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.8),
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
          children: [
            SheetTitle(record.name),
            if (phone != null) ...[
              const SizedBox(height: 4),
              Text(phone, style: muted),
              const SizedBox(height: 12),
              ContactRow(phone: phone),
            ],
            if (record.isRegular) ...[
              const SizedBox(height: 16),
              Text(AppStrings.regularBookings, style: text.titleSmall),
              for (final r in record.regulars)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.event_repeat_rounded, color: AppColors.primaryDeep),
                  title: Text(AppStrings.everyWeekday(r.weekday, r.startHour, r.endHour)),
                ),
            ],
            if (record.bookings.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text(AppStrings.timesBooked(record.bookings.length), style: text.titleSmall),
              for (final b in record.bookings)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(AppStrings.bookingTime(b.startsAt, b.endsAt)),
                  subtitle: Text([
                    AppStrings.bookingStatusLabel(b.status,
                        expired: b.status == BookingStatus.cancelled && b.cancelledBy == null),
                    PriceUtils.nu(b.priceNu),
                    if (b.isPhone) AppStrings.byPhone,
                  ].join(' · ')),
                ),
            ],
          ],
        ),
      ),
    );
  }
}
