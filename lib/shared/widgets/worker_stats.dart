import 'package:flutter/material.dart';

import '../../core/strings/app_strings.dart';
import '../../core/theme/app_colors.dart';
import '../models/worker_listing.dart';

/// Rating, number of reviews and years of work in three boxes (C3, B5).
class WorkerStats extends StatelessWidget {
  final WorkerListing worker;

  const WorkerStats({super.key, required this.worker});

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: _Stat(
              icon: Icons.star_rounded,
              iconColor: AppColors.saffron,
              value: worker.reviewCount == 0
                  ? AppStrings.newWorker
                  : worker.avgRating.toStringAsFixed(1),
              label: AppStrings.rating,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _Stat(
              icon: Icons.reviews_outlined,
              value: '${worker.reviewCount}',
              label: AppStrings.reviews,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _Stat(
              icon: Icons.work_history_outlined,
              value: '${worker.yearsExperience}',
              label: AppStrings.yearsLabel,
            ),
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String value;
  final String label;

  const _Stat({
    required this.icon,
    required this.value,
    required this.label,
    this.iconColor = AppColors.primaryDeep,
  });

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Semantics(
      label: '$label: $value',
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(color: AppColors.ivory, borderRadius: BorderRadius.circular(16)),
        child: Column(
          children: [
            Icon(icon, color: iconColor),
            const SizedBox(height: 4),
            Text(value, style: text.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
            Text(label, textAlign: TextAlign.center, style: text.bodySmall),
          ],
        ),
      ),
    );
  }
}
