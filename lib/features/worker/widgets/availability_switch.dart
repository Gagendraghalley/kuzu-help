import 'package:flutter/material.dart';

import '../../../core/strings/app_strings.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/icon_tile.dart';

/// 'Available for work' on/off switch (B5). [onChanged] is null while saving.
class AvailabilitySwitch extends StatelessWidget {
  final bool value;
  final ValueChanged<bool>? onChanged;

  const AvailabilitySwitch({super.key, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final color = value ? AppColors.verified : AppColors.muted;

    return Card(
      color: value ? Color.alphaBlend(AppColors.verified.withValues(alpha: 0.06), Colors.white) : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: value ? AppColors.verified.withValues(alpha: 0.35) : AppColors.line),
      ),
      child: SwitchListTile(
        value: value,
        onChanged: onChanged,
        activeTrackColor: AppColors.verified,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        secondary: IconTile(icon: value ? Icons.work_rounded : Icons.work_off_outlined, color: color, size: 48),
        title: Text(
          value ? AppStrings.availableForWork : AppStrings.notAvailable,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
        ),
        subtitle: Text(value ? AppStrings.availableHint : AppStrings.notAvailableHint),
      ),
    );
  }
}
