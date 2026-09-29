import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/strings/app_strings.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/error_messages.dart';
import '../../../shared/models/app_notification.dart';
import '../../../shared/widgets/async_view.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/icon_tile.dart';
import '../data/notification_repository.dart';
import '../open_notification.dart';
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
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  itemCount: notifications.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final n = notification;
    final body = AppStrings.notificationBody(n.type, n.data);
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;

    return Card(
      color: n.isRead ? null : const Color(0xFFFFF8F1),
      shape: n.isRead
          ? null
          : RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: BorderSide(color: AppColors.primary.withValues(alpha: 0.28)),
            ),
      child: ListTile(
        contentPadding: const EdgeInsets.fromLTRB(16, 8, 14, 8),
        leading: IconTile(icon: _icon(n.type), size: 44, color: n.isRead ? AppColors.muted : AppColors.primaryDeep),
        title: Text(
          AppStrings.notificationTitle(n.type, n.data),
          style: TextStyle(fontWeight: n.isRead ? FontWeight.w600 : FontWeight.w800),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (body.isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(body, style: const TextStyle(color: AppColors.inkSoft)),
            ],
            const SizedBox(height: 6),
            Text(AppStrings.timeAgo(n.createdAt), style: TextStyle(color: muted, fontSize: 13, fontWeight: FontWeight.w500)),
          ],
        ),
        trailing: n.isRead
            ? null
            : Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                  boxShadow: [BoxShadow(color: AppColors.primary.withValues(alpha: 0.4), blurRadius: 6)],
                ),
              ),
        onTap: () => openNotification(context, ref, n),
      ),
    );
  }
}
