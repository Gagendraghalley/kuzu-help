import 'package:flutter/material.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/strings/app_strings.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/models/ground_booking.dart';
import '../../../shared/models/subscription.dart';
import '../../../shared/models/venue.dart';

/// A short status in a soft pill of [color]: a booking's, a venue's.
class StatusPill extends StatelessWidget {
  final String label;
  final Color color;

  const StatusPill({super.key, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Color.alphaBlend(color.withValues(alpha: 0.1), Colors.white),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 13)),
    );
  }
}

/// A booking's status: green once confirmed or played, orange while waiting,
/// grey when it didn't happen. Blocked time says so.
class BookingStatusChip extends StatelessWidget {
  final GroundBooking booking;

  const BookingStatusChip({super.key, required this.booking});

  @override
  Widget build(BuildContext context) {
    if (booking.isBlock) {
      return StatusPill(
        label: AppStrings.blockedFor(null),
        color: booking.isOpen ? AppColors.maroon : AppColors.unavailable,
      );
    }
    final status = booking.status;
    return StatusPill(
      label: AppStrings.bookingStatusLabel(status,
          expired: status == BookingStatus.cancelled && booking.cancelledBy == null),
      color: switch (status) {
        BookingStatus.confirmed || BookingStatus.completed => AppColors.verified,
        BookingStatus.pending => AppColors.primaryDeep,
        _ => AppColors.unavailable,
      },
    );
  }
}

/// A venue's status for its manager and admins: taking bookings, paused,
/// hidden (its subscription has ended), or no manager yet (so nobody can
/// book it).
class VenueStatusPill extends StatelessWidget {
  final Venue venue;

  const VenueStatusPill({super.key, required this.venue});

  @override
  Widget build(BuildContext context) {
    return StatusPill(
      label: AppStrings.venueStatusLabel(
          active: venue.isActive, hasManager: venue.hasManager, subscriptionEnded: venue.subscriptionEnded),
      color: !venue.hasManager || venue.subscriptionEnded
          ? AppColors.error
          : venue.isActive
              ? AppColors.verified
              : AppColors.unavailable,
    );
  }
}

/// A ground's subscription for its manager and admins: green while it has
/// time, orange in its last days (pay for the next month), red once it has
/// ended (players can't find it).
class SubscriptionPill extends StatelessWidget {
  final VenueSubscription subscription;

  const SubscriptionPill({super.key, required this.subscription});

  @override
  Widget build(BuildContext context) {
    final s = subscription;
    if (s.isEnded()) return const StatusPill(label: AppStrings.subscriptionEnded, color: AppColors.error);
    if (s.endsSoon()) {
      return StatusPill(label: AppStrings.subscriptionDaysLeft(s.kind, s.daysLeft()), color: AppColors.primaryDeep);
    }
    return StatusPill(label: AppStrings.subscriptionUntil(s.kind, s.lastDay), color: AppColors.verified);
  }
}
