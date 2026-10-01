import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_constants.dart';
import '../../core/router/route_names.dart';
import '../../shared/models/app_notification.dart';
import '../admin/providers/admin_providers.dart';
import '../customer/providers/worker_details_providers.dart';
import '../grounds/providers/booking_providers.dart';
import '../grounds/providers/venue_providers.dart';
import '../jobs/providers/job_providers.dart';
import '../profile/providers/profile_providers.dart';
import 'data/notification_repository.dart';

/// Marks [n] read (if saving fails it stays unread, and opening it again
/// retries), then opens what it's about. From the Notifications list, and
/// from a push notification the user tapped.
void openNotification(BuildContext context, WidgetRef ref, AppNotification n) {
  if (!n.isRead) ref.read(notificationRepositoryProvider).markRead(n.id).ignore();

  final workerId = n.workerId;
  final venueId = n.venueId;
  switch (n.type) {
    case NotificationTypes.newUser:
      context.push(Routes.users);
    case NotificationTypes.reportNew:
      ref.invalidate(reportsProvider);
      context.push(Routes.reports);
    case NotificationTypes.jobNew ||
          NotificationTypes.jobAccepted ||
          NotificationTypes.jobDeclined ||
          NotificationTypes.jobCancelled ||
          NotificationTypes.jobCompleted:
      ref.invalidate(myJobsProvider);
      context.push(Routes.jobs);
    // The worker's page: the Admin check card for admins, reviews for the
    // worker. Reloaded, as it may have changed since it was last opened.
    case NotificationTypes.workerSubmitted ||
          NotificationTypes.workerResubmitted ||
          NotificationTypes.reviewNew ||
          NotificationTypes.reviewUpdated ||
          NotificationTypes.reviewReply
        when workerId != null:
      ref.invalidate(workerDetailsProvider(workerId));
      ref.invalidate(workerReviewsProvider(workerId));
      context.push(Routes.workerDetailsFor(workerId));
    // The splash (A1) opens the dashboard or the status screen with the note.
    case NotificationTypes.workerApproved || NotificationTypes.workerRejected:
      context.go(Routes.splash);
    // Sports grounds. Managers: their venue's bookings, or its page with the
    // reviews; someone just given a venue starts again on the splash (A1),
    // which now opens their venue. Customers: My bookings.
    case NotificationTypes.venueAssigned:
      ref.invalidate(myProfileProvider); // now a venue manager
      context.go(Routes.splash);
    case NotificationTypes.venueReviewNew || NotificationTypes.venueReviewUpdated when venueId != null:
      ref.invalidate(venueDetailsProvider(venueId));
      ref.invalidate(venueReviewsProvider(venueId));
      context.push(Routes.venueDetailsFor(venueId));
    case NotificationTypes.bookingNew || NotificationTypes.bookingCancelled
        when venueId != null && (n.type == NotificationTypes.bookingNew || n.data['by'] == 'customer'):
      ref.invalidate(venueBookingsProvider(venueId));
      context.push(Routes.venueBookingsFor(venueId));
    case NotificationTypes.bookingConfirmed ||
          NotificationTypes.bookingRejected ||
          NotificationTypes.bookingCancelled ||
          NotificationTypes.bookingExpired ||
          NotificationTypes.bookingCompleted:
      ref.invalidate(myBookingsProvider);
      context.push(Routes.myBookings);
  }
}
