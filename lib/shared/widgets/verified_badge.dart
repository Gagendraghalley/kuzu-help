import 'package:flutter/material.dart';

import '../../core/constants/app_constants.dart';
import '../../core/strings/app_strings.dart';
import '../../core/theme/app_colors.dart';

/// Small green 'Verified' badge. Admins also see workers who aren't approved:
/// for them it says 'Awaiting approval' or 'Not approved'.
class VerifiedBadge extends StatelessWidget {
  final String status;

  const VerifiedBadge({super.key, this.status = VerificationStatus.approved});

  @override
  Widget build(BuildContext context) {
    return switch (status) {
      VerificationStatus.approved =>
        const _Tag(color: AppColors.verified, icon: Icons.verified_rounded, label: AppStrings.verified),
      VerificationStatus.rejected =>
        const _Tag(color: AppColors.error, icon: Icons.block_rounded, label: AppStrings.notApproved),
      _ => const _Tag(
          color: AppColors.primaryDeep,
          icon: Icons.hourglass_top_rounded,
          label: AppStrings.awaitingApproval,
        ),
    };
  }
}

/// Red 'Deactivated': admins only ever see deactivated users.
class DeactivatedBadge extends StatelessWidget {
  const DeactivatedBadge({super.key});

  @override
  Widget build(BuildContext context) =>
      const _Tag(color: AppColors.error, icon: Icons.block_rounded, label: AppStrings.deactivated);
}

/// Green 'Available' or grey 'Not available' (worker cards, C3).
class AvailabilityLabel extends StatelessWidget {
  final bool isAvailable;

  const AvailabilityLabel({super.key, required this.isAvailable});

  @override
  Widget build(BuildContext context) {
    return _Tag(
      color: isAvailable ? AppColors.verified : Theme.of(context).colorScheme.onSurfaceVariant,
      icon: Icons.circle,
      iconSize: 8,
      label: isAvailable ? AppStrings.available : AppStrings.notAvailable,
    );
  }
}

class _Tag extends StatelessWidget {
  final Color color;
  final IconData icon;
  final double iconSize;
  final String label;

  const _Tag({required this.color, required this.icon, required this.label, this.iconSize = 15});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Color.alphaBlend(color.withValues(alpha: 0.09), Colors.white),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: iconSize, color: color),
          const SizedBox(width: 6),
          // Wraps rather than overflowing on narrow cards or with large text.
          Flexible(
            child: Text(
              label,
              style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 13.5, height: 1.2),
            ),
          ),
        ],
      ),
    );
  }
}
