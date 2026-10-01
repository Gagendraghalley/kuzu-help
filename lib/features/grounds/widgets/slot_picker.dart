import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/strings/app_strings.dart';
import '../../../core/utils/bhutan_time.dart';
import '../../../shared/models/ground.dart';
import '../../../shared/models/ground_booking.dart';
import '../../../shared/widgets/info_note.dart';
import '../providers/venue_providers.dart';

/// The ground's times on the day that haven't started. Only free ones can
/// be chosen; one someone has says so ('6 pm – 8 pm · Booked', '· Regular
/// booking'), for everyone looking.
class SlotPicker extends ConsumerWidget {
  final Ground ground;
  final DateTime day;
  final Set<TimeSlot> selected; // more than one: several chosen at once (regular bookings)
  final ValueChanged<TimeSlot> onSelected;

  const SlotPicker({super.key, required this.ground, required this.day, required this.selected, required this.onSelected});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final slots = ground.slotsOn(day);
    if (slots.isEmpty) return const InfoNote(icon: Icons.event_busy_outlined, text: AppStrings.closedThisDay);
    final key = (groundId: ground.id, day: day);

    return ref.watch(availabilityProvider(key)).when(
          loading: () => const SizedBox(height: 80, child: Center(child: CircularProgressIndicator())),
          error: (_, __) => Row(
            children: [
              const Expanded(child: Text(AppStrings.genericError)),
              TextButton(onPressed: () => ref.invalidate(availabilityProvider(key)), child: const Text(AppStrings.retry)),
            ],
          ),
          data: (busy) {
            final now = DateTime.now();
            final upcoming = [
              for (final slot in slots)
                if (BhutanTime.at(day, slot.startHour).isAfter(now)) slot,
            ];
            if (upcoming.isEmpty) return const InfoNote(icon: Icons.event_busy_outlined, text: AppStrings.noFreeTimes);

            bool isExactly(BusyTime b, TimeSlot slot) =>
                !b.blocked && b.start == BhutanTime.at(day, slot.startHour) && b.end == BhutanTime.at(day, slot.endHour);

            // What's taken during the slot: a booking of exactly that time
            // first, so it reads 'Booked' rather than 'Not available'.
            BusyTime? takenBy(TimeSlot slot) {
              final start = BhutanTime.at(day, slot.startHour);
              final end = BhutanTime.at(day, slot.endHour);
              final overlapping = busy.where((b) => b.start.isBefore(end) && b.end.isAfter(start));
              return overlapping.where((b) => isExactly(b, slot)).firstOrNull ?? overlapping.firstOrNull;
            }

            final taken = {for (final slot in upcoming) slot: takenBy(slot)};
            String label(TimeSlot slot) => switch (taken[slot]) {
                  final b? => AppStrings.takenSlot(slot.startHour, slot.endHour,
                      exact: isExactly(b, slot), confirmed: b.confirmed, regular: b.regular),
                  null => AppStrings.hoursRange(slot.startHour, slot.endHour),
                };
            final muted = TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant);

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (taken.values.every((t) => t != null)) ...[
                  const InfoNote(icon: Icons.event_busy_outlined, text: AppStrings.noFreeTimes),
                  const SizedBox(height: 12),
                ],
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final slot in upcoming)
                      ChoiceChip(
                        label: Text(label(slot)),
                        selected: selected.contains(slot),
                        onSelected: taken[slot] == null ? (_) => onSelected(slot) : null,
                      ),
                  ],
                ),
                if (taken.values.any((t) => t != null)) ...[
                  const SizedBox(height: 10),
                  Text(AppStrings.takenTimesNote, style: muted),
                ],
              ],
            );
          },
        );
  }
}
