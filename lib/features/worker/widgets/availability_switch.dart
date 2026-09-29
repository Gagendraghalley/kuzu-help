import 'package:flutter/material.dart';

import '../../../core/strings/app_strings.dart';
import '../../../core/theme/app_colors.dart';

/// 'Available for work' on/off switch (B5). [onChanged] is null while saving.
class AvailabilitySwitch extends StatelessWidget {
  final bool value;
  final ValueChanged<bool>? onChanged;

  const AvailabilitySwitch({super.key, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final color = value ? AppColors.verified : Theme.of(context).colorScheme.onSurfaceVariant;

    return Card(
      color: color.withValues(alpha: 0.08),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: color.withValues(alpha: 0.4)),
      ),
      child: SwitchListTile(
        value: value,
        onChanged: onChanged,
        activeTrackColor: AppColors.verified,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        secondary: Icon(value ? Icons.work : Icons.work_off_outlined, color: color, size: 32),
        title: Text(
          value ? AppStrings.availableForWork : AppStrings.notAvailable,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(value ? AppStrings.availableHint : AppStrings.notAvailableHint),
      ),
    );
  }
}
