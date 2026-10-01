import 'package:flutter/material.dart';

import '../../../core/strings/app_strings.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/models/ground.dart';

/// Each day of the week, Monday first, with the times people can book on it:
/// as many as the manager likes, each from one hour to another. [slots] is
/// by weekday (0 = Sunday); an empty list: closed that day.
class TimeSlotsEditor extends StatelessWidget {
  final Map<int, List<TimeSlot>> slots;
  final void Function(int weekday, List<TimeSlot> slots) onChanged;

  const TimeSlotsEditor({super.key, required this.slots, required this.onChanged});

  /// Monday first, as people read a week.
  static const week = [1, 2, 3, 4, 5, 6, 0];

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        child: Column(
          children: [
            for (final (i, day) in week.indexed) ...[
              if (i > 0) const Divider(),
              _DaySlots(weekday: day, slots: slots[day] ?? const [], onChanged: (s) => onChanged(day, s)),
            ],
          ],
        ),
      ),
    );
  }
}

class _DaySlots extends StatelessWidget {
  final int weekday;
  final List<TimeSlot> slots;
  final ValueChanged<List<TimeSlot>> onChanged;

  const _DaySlots({required this.weekday, required this.slots, required this.onChanged});

  /// A new time: after the day's last one, two hours long; 6 to 8 pm on an empty day.
  TimeSlot _next() {
    final last = slots.lastOrNull;
    final start = last == null ? 18 : (last.endHour >= 24 ? 22 : last.endHour);
    return TimeSlot(weekday: weekday, startHour: start, endHour: start + 2 > 24 ? 24 : start + 2);
  }

  void _replace(int i, TimeSlot slot) => onChanged([...slots]..[i] = slot);

  @override
  Widget build(BuildContext context) {
    Widget hourMenu(int value, Iterable<int> choices, ValueChanged<int> onSelected) => DropdownButton<int>(
          value: value,
          isDense: true,
          underline: const SizedBox.shrink(),
          borderRadius: BorderRadius.circular(16),
          dropdownColor: Colors.white,
          menuMaxHeight: 400,
          items: [for (final h in choices) DropdownMenuItem(value: h, child: Text(AppStrings.hourLabel(h)))],
          onChanged: (h) {
            if (h != null) onSelected(h);
          },
        );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              SizedBox(
                width: 48,
                child: Text(AppStrings.weekdayName(weekday), style: const TextStyle(fontWeight: FontWeight.w800)),
              ),
              Expanded(
                child: slots.isEmpty
                    ? const Text(AppStrings.closed, style: TextStyle(color: AppColors.muted))
                    : const SizedBox.shrink(),
              ),
              TextButton.icon(
                style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                ),
                icon: const Icon(Icons.add_rounded, size: 20),
                label: const Text(AppStrings.addTime),
                onPressed: () => onChanged([...slots, _next()]),
              ),
            ],
          ),
          for (final (i, slot) in slots.indexed)
            Padding(
              padding: const EdgeInsets.only(left: 12),
              child: Row(
                children: [
                  hourMenu(
                    slot.startHour,
                    [for (var h = 0; h < slot.endHour; h++) h],
                    (h) => _replace(i, TimeSlot(weekday: weekday, startHour: h, endHour: slot.endHour)),
                  ),
                  const Padding(padding: EdgeInsets.symmetric(horizontal: 8), child: Text('–')),
                  hourMenu(
                    slot.endHour,
                    [for (var h = slot.startHour + 1; h <= 24; h++) h],
                    (h) => _replace(i, TimeSlot(weekday: weekday, startHour: slot.startHour, endHour: h)),
                  ),
                  const Spacer(),
                  IconButton(
                    tooltip: AppStrings.removeTime,
                    visualDensity: VisualDensity.compact,
                    icon: const Icon(Icons.close_rounded, color: AppColors.muted),
                    onPressed: () => onChanged([...slots]..removeAt(i)),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
