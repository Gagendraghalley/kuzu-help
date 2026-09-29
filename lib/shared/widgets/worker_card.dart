import 'package:flutter/material.dart';

import '../../core/strings/app_strings.dart';
import '../../core/theme/app_colors.dart';
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
    final priceNote = this.priceNote;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AvatarImage(url: worker.avatarUrl, name: worker.fullName, size: 64),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      worker.fullName,
                      style: text.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        if (!worker.isActive) const DeactivatedBadge(),
                        VerifiedBadge(status: worker.verificationStatus),
                        AvailabilityLabel(isAvailable: worker.isAvailable),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(Icons.location_on_outlined, size: 18, color: muted),
                        const SizedBox(width: 4),
                        Expanded(child: Text(worker.location, style: TextStyle(color: muted))),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.star_rounded, size: 20, color: AppColors.saffron),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            worker.reviewCount == 0
                                ? '${AppStrings.noReviewsShort} · ${AppStrings.years(worker.yearsExperience)}'
                                : '${worker.avgRating.toStringAsFixed(1)} '
                                    '(${AppStrings.reviewCount(worker.reviewCount)}) · '
                                    '${AppStrings.years(worker.yearsExperience)}',
                          ),
                        ),
                      ],
                    ),
                    if (priceNote != null && priceNote.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        priceNote,
                        style: const TextStyle(color: AppColors.primaryDeep, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: muted),
            ],
          ),
        ),
      ),
    );
  }
}
