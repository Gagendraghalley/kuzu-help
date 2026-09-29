import 'package:flutter/material.dart';

import '../../../core/strings/app_strings.dart';
import '../../../core/theme/app_colors.dart';

/// 'Step 2 of 3' over one bar per step, on B1–B3 during first setup.
class SetupProgress extends StatelessWidget {
  final int step;

  const SetupProgress({super.key, required this.step});

  static const steps = 3;

  @override
  Widget build(BuildContext context) {
    final label = AppStrings.setupStep(step, steps);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: AppColors.primaryDeep,
                fontWeight: FontWeight.w800,
              ),
        ),
        const SizedBox(height: 10),
        ExcludeSemantics(
          child: Row(
            children: [
              for (var i = 1; i <= steps; i++) ...[
                if (i > 1) const SizedBox(width: 6),
                Expanded(
                  child: Container(
                    height: 6,
                    decoration: BoxDecoration(
                      color: i <= step ? AppColors.primaryDeep : AppColors.sand,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
