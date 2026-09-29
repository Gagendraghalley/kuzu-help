import 'package:flutter/material.dart';

import '../../core/strings/app_strings.dart';
import '../../core/theme/app_colors.dart';
import '../models/worker_listing.dart';

/// Rating, number of reviews and years of work side by side (C3, B5): in a
/// white card, or in white text on a BrandPanel when [onBrand].
class WorkerStats extends StatelessWidget {
  final WorkerListing worker;
  final bool onBrand;

  const WorkerStats({super.key, required this.worker, this.onBrand = false});

  @override
  Widget build(BuildContext context) {
    final divider = VerticalDivider(
      width: 1,
      indent: 14,
      endIndent: 14,
      color: onBrand ? Colors.white.withValues(alpha: 0.22) : AppColors.line,
    );
    final row = IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: _Stat(
              icon: Icons.star_rounded,
              iconColor: AppColors.saffron,
              onBrand: onBrand,
              value: worker.reviewCount == 0
                  ? AppStrings.newWorker
                  : worker.avgRating.toStringAsFixed(1),
              label: AppStrings.rating,
            ),
          ),
          divider,
          Expanded(
            child: _Stat(
              icon: Icons.reviews_outlined,
              onBrand: onBrand,
              value: '${worker.reviewCount}',
              label: AppStrings.reviews,
            ),
          ),
          divider,
          Expanded(
            child: _Stat(
              icon: Icons.work_history_outlined,
              onBrand: onBrand,
              value: '${worker.yearsExperience}',
              label: AppStrings.yearsLabel,
            ),
          ),
        ],
      ),
    );

    if (onBrand) {
      return DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
        ),
        child: row,
      );
    }
    return Card(child: row);
  }
}

class _Stat extends StatelessWidget {
  final IconData icon;
  final Color? iconColor;
  final String value;
  final String label;
  final bool onBrand;

  const _Stat({
    required this.icon,
    required this.value,
    required this.label,
    required this.onBrand,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final ink = onBrand ? Colors.white : AppColors.ink;
    final soft = onBrand ? Colors.white.withValues(alpha: 0.85) : AppColors.muted;
    return Semantics(
      label: '$label: $value',
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
        child: Column(
          children: [
            Icon(icon, size: 22, color: iconColor ?? (onBrand ? Colors.white : AppColors.primaryDeep)),
            const SizedBox(height: 6),
            Text(value, style: text.titleLarge?.copyWith(fontWeight: FontWeight.w800, color: ink, height: 1.1)),
            const SizedBox(height: 2),
            Text(label, textAlign: TextAlign.center, style: text.bodySmall?.copyWith(color: soft)),
          ],
        ),
      ),
    );
  }
}
