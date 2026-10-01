import 'package:flutter/material.dart';

import '../../../core/strings/app_strings.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/models/venue.dart';

/// A venue's cover photo, or the brand colours with a ball when it has none.
class VenueCover extends StatelessWidget {
  final String? url;
  final double height;

  const VenueCover({super.key, required this.url, this.height = 132});

  @override
  Widget build(BuildContext context) {
    const placeholder = DecoratedBox(
      decoration: BoxDecoration(gradient: AppColors.brandGradient),
      child: Center(child: Icon(Icons.sports_soccer_rounded, size: 52, color: Colors.white70)),
    );
    final url = this.url;
    return SizedBox(
      height: height,
      width: double.infinity,
      child: url == null
          ? placeholder
          : Image.network(url, fit: BoxFit.cover, errorBuilder: (_, __, ___) => placeholder),
    );
  }
}

/// Card: cover photo, name, place, rating, sports and the lowest price. For
/// its manager and admins, [status] shows instead of the price.
class VenueCard extends StatelessWidget {
  final Venue venue;
  final VoidCallback onTap;
  final Widget? status;

  const VenueCard({super.key, required this.venue, required this.onTap, this.status});

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    final price = venue.fromPriceNu;
    final status = this.status;

    return Card(
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            VenueCover(url: venue.coverUrl),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(venue.name, style: text.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.location_on_outlined, size: 17, color: muted),
                      const SizedBox(width: 4),
                      Expanded(child: Text(venue.location, style: TextStyle(color: muted, fontSize: 14.5))),
                    ],
                  ),
                  if (status == null) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.star_rounded, size: 19, color: AppColors.saffron),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            venue.reviewCount == 0
                                ? AppStrings.noReviewsShort
                                : '${venue.avgRating.toStringAsFixed(1)} (${AppStrings.reviewCount(venue.reviewCount)})',
                            style: const TextStyle(
                                fontSize: 14.5, fontWeight: FontWeight.w600, color: AppColors.inkSoft),
                          ),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      if (status != null) status,
                      if (status == null && price != null) _Tag(AppStrings.fromPricePerHour(price), strong: true),
                      for (final sport in venue.sports) _Tag(AppStrings.sportLabel(sport)),
                      if (status == null && venue.autoConfirm) const _Tag(AppStrings.instantBooking, icon: Icons.bolt_rounded),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  final String label;
  final bool strong;
  final IconData? icon;

  const _Tag(this.label, {this.strong = false, this.icon});

  @override
  Widget build(BuildContext context) {
    final icon = this.icon;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: strong ? AppColors.peach : AppColors.canvas,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 16, color: AppColors.primaryDeep),
            const SizedBox(width: 2),
          ],
          Text(
            label,
            style: TextStyle(
              color: strong ? AppColors.primaryDeep : AppColors.inkSoft,
              fontWeight: strong ? FontWeight.w700 : FontWeight.w600,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}
