import 'package:flutter/material.dart';

import '../../../core/strings/app_strings.dart';

/// 'Step 2 of 3' with a bar, on B1–B3 during first setup.
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
                color: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(value: step / steps, minHeight: 6, semanticsLabel: label),
        ),
      ],
    );
  }
}
