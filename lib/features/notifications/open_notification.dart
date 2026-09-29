import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_constants.dart';
import '../../core/router/route_names.dart';
import '../../shared/models/app_notification.dart';
import '../admin/providers/admin_providers.dart';
import '../customer/providers/worker_details_providers.dart';
import '../jobs/providers/job_providers.dart';
import 'data/notification_repository.dart';

/// Marks [n] read (if saving fails it stays unread, and opening it again
/// retries), then opens what it's about. From the Notifications list, and
/// from a push notification the user tapped.
void openNotification(BuildContext context, WidgetRef ref, AppNotification n) {
  if (!n.isRead) ref.read(notificationRepositoryProvider).markRead(n.id).ignore();

  final workerId = n.workerId;
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
  }
}
