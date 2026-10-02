import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/route_names.dart';
import '../../../core/strings/app_strings.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/models/venue.dart';
import '../../../shared/widgets/icon_tile.dart';
import 'status_pill.dart';

/// On the screen that runs a ground (its manager's and admins'): how long
/// players can find it, and the way to its Subscription page. Orange in its
/// last days, with what to pay; red once it has ended.
class SubscriptionCard extends StatelessWidget {
  final Venue venue;

  const SubscriptionCard({super.key, required this.venue});

  @override
  Widget build(BuildContext context) {
    final s = venue.subscription;
    if (s == null) return const SizedBox.shrink();
    final ended = s.isEnded();
    final soon = s.endsSoon();
    final tint = ended ? AppColors.error : soon ? AppColors.primary : null;

    return Card(
      color: tint == null ? null : Color.alphaBlend(tint.withValues(alpha: 0.06), Colors.white),
      shape: tint == null
          ? null
          : RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: BorderSide(color: tint.withValues(alpha: 0.4)),
            ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        leading: IconTile(
          icon: ended ? Icons.visibility_off_outlined : Icons.receipt_long_outlined,
          color: ended ? AppColors.error : AppColors.primaryDeep,
          size: 44,
        ),
        title: const Text(AppStrings.subscription, style: TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 6),
            SubscriptionPill(subscription: s),
            if (ended || soon) ...[
              const SizedBox(height: 6),
              Text(
                ended ? AppStrings.payToListAgain(s.feeNu) : AppStrings.payNextMonth(s.feeNu),
                style: TextStyle(color: ended ? AppColors.error : AppColors.primaryDeep, fontWeight: FontWeight.w600),
              ),
            ],
          ],
        ),
        trailing: const Icon(Icons.chevron_right_rounded, color: AppColors.muted),
        onTap: () => context.push(Routes.venueSubscriptionFor(venue.id)),
      ),
    );
  }
}
