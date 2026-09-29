import 'package:flutter/material.dart';

import '../../core/strings/app_strings.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/price_utils.dart';
import '../models/worker_listing.dart';
import 'avatar_image.dart';
import 'verified_badge.dart';

/// Card: photo, name, town, rating, review count, verified badge, availability.
class WorkerCard extends StatelessWidget {
  final WorkerListing worker;
  final String? priceNote;
  final VoidCallback onTap;

  const WorkerCard({super.key, required this.worker, required this.onTap, this.priceNote});

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    final priceNote = PriceUtils.display(this.priceNote);

    return Card(
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AvatarImage(url: worker.avatarUrl, name: worker.fullName, size: 64),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      worker.fullName,
                      style: text.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.location_on_outlined, size: 17, color: muted),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(worker.location, style: TextStyle(color: muted, fontSize: 14.5)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.star_rounded, size: 19, color: AppColors.saffron),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            worker.reviewCount == 0
                                ? '${AppStrings.noReviewsShort} · ${AppStrings.years(worker.yearsExperience)}'
                                : '${worker.avgRating.toStringAsFixed(1)} '
                                    '(${AppStrings.reviewCount(worker.reviewCount)}) · '
                                    '${AppStrings.years(worker.yearsExperience)}',
                            style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600, color: AppColors.inkSoft),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        if (!worker.isActive) const DeactivatedBadge(),
                        VerifiedBadge(status: worker.verificationStatus),
                        AvailabilityLabel(isAvailable: worker.isAvailable),
                      ],
                    ),
                    if (priceNote != null && priceNote.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppColors.peach,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          priceNote,
                          style: const TextStyle(color: AppColors.primaryDeep, fontWeight: FontWeight.w700, fontSize: 14.5),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 4),
              Padding(
                padding: const EdgeInsets.only(top: 20),
                child: Icon(Icons.chevron_right_rounded, color: muted),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
