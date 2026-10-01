import 'package:flutter/material.dart';

import '../../../core/strings/app_strings.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/price_utils.dart';

/// A booking about to be made: when, and what it costs. With [onRemove], a
/// button to take it off (one of several chosen).
class BookingSummary extends StatelessWidget {
  final String when;
  final int price;
  final VoidCallback? onRemove;

  const BookingSummary({super.key, required this.when, required this.price, this.onRemove});

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.peach,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.event_available_rounded, color: AppColors.primaryDeep),
          const SizedBox(width: 12),
          Expanded(child: Text(when, style: text.titleSmall?.copyWith(color: AppColors.maroon))),
          const SizedBox(width: 8),
          Text(PriceUtils.nu(price),
              style: text.titleMedium?.copyWith(color: AppColors.primaryDeep, fontWeight: FontWeight.w800)),
          if (onRemove != null)
            IconButton(
              tooltip: AppStrings.removeTime,
              visualDensity: VisualDensity.compact,
              icon: const Icon(Icons.close_rounded, color: AppColors.maroon),
              onPressed: onRemove,
            ),
        ],
      ),
    );
  }
}
