import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/router/route_names.dart';
import '../../../core/strings/app_strings.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/error_messages.dart';
import '../../../shared/models/app_notification.dart';
import '../../../shared/widgets/async_view.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../admin/providers/admin_providers.dart';
import '../../customer/providers/worker_details_providers.dart';
import '../../jobs/providers/job_providers.dart';
import '../data/notification_repository.dart';
import '../providers/notification_providers.dart';

/// Notifications
/// Purpose: Tell each user what has happened that concerns them.
/// Backend: Reads the user's notifications live; marks them read.
/// Done when: A new one shows on the bell at once, and tapping it opens what
/// it's about.
class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  Future<void> _markAllRead(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(notificationRepositoryProvider).markAllRead();
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(ErrorMessages.from(e))));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifications = ref.watch(myNotificationsProvider);
    final unread = ref.watch(unreadNotificationCountProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text(AppStrings.notifications),
        centerTitle: false,
        actions: [
          if (unread > 0)
            TextButton(
              onPressed: () => _markAllRead(context, ref),
              child: const Text(AppStrings.markAllRead),
            ),
        ],
      ),
      body: SafeArea(
        child: AsyncView(
          value: notifications,
          onRetry: () => ref.invalidate(myNotificationsProvider),
          data: (notifications) => notifications.isEmpty
              ? const EmptyState(icon: Icons.notifications_none, message: AppStrings.noNotifications)
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: notifications.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, i) => _NotificationTile(notification: notifications[i]),
                ),
        ),
      ),
    );
  }
}

class _NotificationTile extends ConsumerWidget {
  final AppNotification notification;

  const _NotificationTile({required this.notification});

  static IconData _icon(String type) => switch (type) {
        NotificationTypes.welcome => Icons.waving_hand_outlined,
        NotificationTypes.newUser => Icons.person_add_alt_1_outlined,
        NotificationTypes.workerSubmitted ||
        NotificationTypes.workerResubmitted =>
          Icons.how_to_reg_outlined,
        NotificationTypes.reportNew || NotificationTypes.reportUpdated => Icons.flag_outlined,
        NotificationTypes.workerApproved => Icons.verified_outlined,
        NotificationTypes.workerRejected => Icons.edit_note,
        NotificationTypes.reviewNew || NotificationTypes.reviewUpdated => Icons.star_outline,
        NotificationTypes.contact => Icons.call_outlined,
        NotificationTypes.accountDeactivated => Icons.block,
        NotificationTypes.accountReactivated => Icons.lock_open,
        NotificationTypes.reviewReply => Icons.reply,
        NotificationTypes.jobNew => Icons.assignment_outlined,
        NotificationTypes.jobAccepted => Icons.event_available,
        NotificationTypes.jobDeclined => Icons.event_busy,
        NotificationTypes.jobCancelled => Icons.cancel_outlined,
        NotificationTypes.jobCompleted => Icons.task_alt,
        _ => Icons.notifications_none,
      };

  /// Marks it read (the list updates itself once saved; if saving fails it
  /// stays unread, and tapping again retries), then opens what it's about.
  void _open(BuildContext context, WidgetRef ref) {
    final n = notification;
    if (!n.isRead) ref.read(notificationRepositoryProvider).markRead(n.id).ignore();

    final workerId = n.workerId;
    switch (n.type) {
      case NotificationTypes.newUser:
        context.push(Routes.users);
      case NotificationTypes.reportNew:
        ref.invalidate(reportsProvider);
        context.push(Routes.reports);
      // The worker's page: the Admin check card for admins, reviews for the
      // worker. Reloaded, as it may have changed since it was last opened.
      case NotificationTypes.jobNew ||
            NotificationTypes.jobAccepted ||
            NotificationTypes.jobDeclined ||
            NotificationTypes.jobCancelled ||
            NotificationTypes.jobCompleted:
        ref.invalidate(myJobsProvider);
        context.push(Routes.jobs);
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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final n = notification;
    final body = AppStrings.notificationBody(n.type, n.data);
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;

    return Card(
      color: n.isRead ? null : AppColors.ivory,
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        contentPadding: const EdgeInsets.fromLTRB(16, 8, 12, 8),
        leading: CircleAvatar(
          backgroundColor: n.isRead ? AppColors.ivory : Colors.white,
          child: Icon(_icon(n.type), color: AppColors.primaryDeep),
        ),
        title: Text(
          AppStrings.notificationTitle(n.type, n.data),
          style: TextStyle(fontWeight: n.isRead ? FontWeight.w500 : FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (body.isNotEmpty) Text(body),
            const SizedBox(height: 4),
            Text(AppStrings.timeAgo(n.createdAt), style: TextStyle(color: muted, fontSize: 13)),
          ],
        ),
        trailing: n.isRead
            ? null
            : Container(
                width: 10,
                height: 10,
                decoration: const BoxDecoration(color: AppColors.primaryDeep, shape: BoxShape.circle),
              ),
        onTap: () => _open(context, ref),
      ),
    );
  }
}
