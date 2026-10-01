import 'package:flutter/material.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/strings/app_strings.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/bhutan_time.dart';

/// The days that can be booked, from today to a week ahead
/// (AppConstants.bookingDaysAhead), one tap each. A dot under the [marked]
/// ones: a time is already chosen there.
class DayStrip extends StatelessWidget {
  final DateTime selected; // a Bhutan day
  final ValueChanged<DateTime> onSelected;
  final Set<DateTime> marked;

  const DayStrip({super.key, required this.selected, required this.onSelected, this.marked = const {}});

  @override
  Widget build(BuildContext context) {
    final today = BhutanTime.today();
    final tomorrow = today.add(const Duration(days: 1));
    final days = [for (var i = 0; i < AppConstants.bookingDaysAhead; i++) today.add(Duration(days: i))];

    return SizedBox(
      height: 76,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: days.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final day = days[i];
          final isSelected = day == selected;
          final name = day == today
              ? AppStrings.today
              : day == tomorrow
                  ? AppStrings.tomorrow
                  : AppStrings.weekdayName(BhutanTime.weekdayOf(day));
          final color = isSelected ? Colors.white : AppColors.ink;
          return Semantics(
            selected: isSelected,
            button: true,
            child: Material(
              color: isSelected ? AppColors.primaryDeep : Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: isSelected ? AppColors.primaryDeep : AppColors.outline, width: 1.2),
              ),
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () => onSelected(day),
                child: SizedBox(
                  width: 84,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(name, style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 14)),
                      const SizedBox(height: 2),
                      Text(AppStrings.dayMonth(day), style: TextStyle(color: color, fontSize: 13.5)),
                      if (marked.contains(day)) ...[
                        const SizedBox(height: 4),
                        Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: isSelected ? Colors.white : AppColors.primaryDeep,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
