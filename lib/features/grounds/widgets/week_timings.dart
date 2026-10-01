import 'package:flutter/material.dart';

import '../../../core/strings/app_strings.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/bhutan_time.dart';
import '../../../shared/models/ground.dart';

/// A ground's timings for the week, as its manager set them: a row for each
/// day, days with the same times together, the day on the left and its
/// times as chips on the right. Today's row stands out, with a badge.
class WeekTimings extends StatelessWidget {
  final Ground ground;

  const WeekTimings({super.key, required this.ground});

  /// Monday first, as the week is shown.
  static int _position(int weekday) => (weekday + 6) % 7;

  @override
  Widget build(BuildContext context) {
    final week = ground.week;
    final today = _position(BhutanTime.weekdayOf(BhutanTime.today()));
    bool isToday(int i) => _position(week[i].from) <= today && today <= _position(week[i].to);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.line),
      ),
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 0; i < week.length; i++) ...[
              // A line between rows, but not around today's tinted one.
              if (i > 0 && !isToday(i) && !isToday(i - 1))
                const Divider(height: 1, thickness: 1, indent: 10, endIndent: 10, color: AppColors.line),
              _DayRow(
                label: week.length == 1 ? AppStrings.everyDay : AppStrings.weekdays(week[i].from, week[i].to),
                slots: week[i].slots,
                isToday: isToday(i),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _DayRow extends StatelessWidget {
  final String label;
  final List<TimeSlot> slots;
  final bool isToday;

  const _DayRow({required this.label, required this.slots, required this.isToday});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 11),
      decoration: isToday
          ? BoxDecoration(color: AppColors.peach.withValues(alpha: 0.7), borderRadius: BorderRadius.circular(12))
          : null,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 88,
            child: Padding(
              padding: const EdgeInsets.only(top: 5),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w700,
                      color: isToday ? AppColors.primaryDeep : AppColors.ink,
                    ),
                  ),
                  if (isToday) ...[
                    const SizedBox(height: 5),
                    const _TodayBadge(),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: slots.isEmpty
                ? const Padding(
                    padding: EdgeInsets.only(top: 5),
                    child: Text(AppStrings.closed,
                        style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.muted)),
                  )
                : Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [for (final slot in slots) _TimeChip(slot: slot, isToday: isToday)],
                  ),
          ),
        ],
      ),
    );
  }
}

/// One bookable time: '6 – 8 pm'.
class _TimeChip extends StatelessWidget {
  final TimeSlot slot;
  final bool isToday;

  const _TimeChip({required this.slot, required this.isToday});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: isToday ? Colors.white : AppColors.canvas,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: isToday ? AppColors.primaryDeep.withValues(alpha: 0.35) : AppColors.line),
      ),
      child: Text(
        AppStrings.hoursShort(slot.startHour, slot.endHour),
        style: TextStyle(
          fontSize: 13.5,
          fontWeight: FontWeight.w600,
          color: isToday ? AppColors.primaryDeep : AppColors.inkSoft,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
    );
  }
}

class _TodayBadge extends StatelessWidget {
  const _TodayBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(color: AppColors.primaryDeep, borderRadius: BorderRadius.circular(6)),
      child: Text(
        AppStrings.today.toUpperCase(),
        style: const TextStyle(color: Colors.white, fontSize: 10.5, fontWeight: FontWeight.w800, letterSpacing: 0.8),
      ),
    );
  }
}
