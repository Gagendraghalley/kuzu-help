import 'package:flutter/material.dart';

import '../../../core/strings/app_strings.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/geo_utils.dart';
import '../../../core/utils/launcher_utils.dart';
import '../../../core/utils/price_utils.dart';
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

/// Card: cover photo, name, place (and how far away, when [distanceKm] is
/// known), rating with 'Directions' once it's on the map, sports and the
/// lowest price. For its manager and admins, [status] shows instead of the
/// price and rating.
class VenueCard extends StatelessWidget {
  final Venue venue;
  final VoidCallback onTap;
  final Widget? status;
  final double? distanceKm;

  const VenueCard({super.key, required this.venue, required this.onTap, this.status, this.distanceKm});

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    final price = venue.fromPriceNu;
    final status = this.status;
    final distanceKm = this.distanceKm;

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
                      if (distanceKm != null) ...[
                        const SizedBox(width: 8),
                        Text(
                          AppStrings.distanceAway(distanceKm),
                          style: const TextStyle(
                              color: AppColors.primaryDeep, fontWeight: FontWeight.w700, fontSize: 14.5),
                        ),
                      ],
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
                        if (venue.coordinates case final place?) _DirectionsLink(place),
                      ],
                    ),
                  ],
                  const SizedBox(height: 10),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        child: Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            if (status != null) status,
                            for (final sport in venue.sports) _Tag(AppStrings.sportLabel(sport)),
                            if (status == null && venue.autoConfirm)
                              const _Tag(AppStrings.instantBooking, icon: Icons.bolt_rounded),
                          ],
                        ),
                      ),
                      if (status == null && price != null) ...[
                        const SizedBox(width: 12),
                        // 'From Nu. 1,500 /hour', the amount standing out.
                        Semantics(
                          label: AppStrings.fromPricePerHour(price),
                          excludeSemantics: true,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              const Text(AppStrings.priceFrom,
                                  style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: AppColors.muted)),
                              PricePerHour(price),
                            ],
                          ),
                        ),
                      ],
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

/// 'Nu. 1,500 /hour': the amount large and bold, the unit small, on one line.
class PricePerHour extends StatelessWidget {
  final int price;
  final double size;

  const PricePerHour(this.price, {super.key, this.size = 19});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Text(
          PriceUtils.nu(price),
          style: TextStyle(
              fontSize: size, fontWeight: FontWeight.w800, letterSpacing: -0.3, color: AppColors.primaryDeep),
        ),
        const SizedBox(width: 2),
        const Text(AppStrings.perHour,
            style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: AppColors.muted)),
      ],
    );
  }
}

/// Google Maps with directions to [place] from where the phone is (the app,
/// when there is one), or says it couldn't open.
Future<void> openDirections(BuildContext context, GeoPoint place) async {
  bool opened;
  try {
    opened = await LauncherUtils.directions(place);
  } catch (_) {
    opened = false;
  }
  if (!opened && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text(AppStrings.cannotOpenMaps)));
  }
}

/// 'Directions' on a card: straight to Google Maps, without opening the venue.
class _DirectionsLink extends StatelessWidget {
  final GeoPoint place;

  const _DirectionsLink(this.place);

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: AppStrings.directions,
      child: Material(
        color: Colors.white,
        shape: const StadiumBorder(side: BorderSide(color: AppColors.primaryDeep)),
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: () => openDirections(context, place),
          child: const Padding(
            padding: EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.directions_rounded, size: 17, color: AppColors.primaryDeep),
                SizedBox(width: 4),
                Text(
                  AppStrings.directionsShort,
                  style: TextStyle(color: AppColors.primaryDeep, fontWeight: FontWeight.w700, fontSize: 13.5),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  final String label;
  final IconData? icon;

  const _Tag(this.label, {this.icon});

  @override
  Widget build(BuildContext context) {
    final icon = this.icon;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(color: AppColors.canvas, borderRadius: BorderRadius.circular(10)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 16, color: AppColors.primaryDeep),
            const SizedBox(width: 2),
          ],
          // Shortens rather than overflows next to the price, with very large text.
          Flexible(
            child: Text(label,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: AppColors.inkSoft, fontWeight: FontWeight.w600, fontSize: 14)),
          ),
        ],
      ),
    );
  }
}
