import 'package:flutter/material.dart';

import '../../../core/strings/app_strings.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/bhutan_time.dart';
import '../../../shared/models/ground.dart';

/// A ground's timings for the week, as its manager set them: each day's
/// times, days with the same times together; today's stand out.
class WeekTimings extends StatelessWidget {
  final Ground ground;

  const WeekTimings({super.key, required this.ground});

  /// Monday first, as the week is shown.
  static int _position(int weekday) => (weekday + 6) % 7;

  @override
  Widget build(BuildContext context) {
    final week = ground.week;
    final today = _position(BhutanTime.weekdayOf(BhutanTime.today()));

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(color: AppColors.ivory, borderRadius: BorderRadius.circular(14)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final days in week)
            Builder(builder: (context) {
              final isToday = _position(days.from) <= today && today <= _position(days.to);
              final style = TextStyle(
                color: isToday ? AppColors.primaryDeep : AppColors.inkSoft,
                fontWeight: isToday ? FontWeight.w700 : FontWeight.w500,
              );
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(week.length == 1 ? AppStrings.everyDay : AppStrings.weekdays(days.from, days.to),
                          style: style),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: days.slots.isEmpty
                          ? [Text(AppStrings.closed, style: style.copyWith(color: AppColors.muted))]
                          : [
                              for (final slot in days.slots)
                                Text(AppStrings.hoursRange(slot.startHour, slot.endHour), style: style),
                            ],
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }
}
