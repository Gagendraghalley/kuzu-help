import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/route_names.dart';
import '../../../core/strings/app_strings.dart';
import '../../../shared/models/app_notification.dart';
import '../data/push_repository.dart';
import '../open_notification.dart';
import '../providers/notification_providers.dart';

/// App bar bell that opens Notifications, showing how many are unread.
/// Every home screen has it, so it also registers the phone for push
/// notifications once someone is logged in, and opens the ones they tap.
class NotificationsButton extends ConsumerStatefulWidget {
  const NotificationsButton({super.key});

  @override
  ConsumerState<NotificationsButton> createState() => _NotificationsButtonState();
}

class _NotificationsButtonState extends ConsumerState<NotificationsButton> {
  StreamSubscription<Map<String, dynamic>>? _taps;

  @override
  void initState() {
    super.initState();
    _taps = ref.read(pushRepositoryProvider).openedNotifications.listen((push) {
      final notification = AppNotification.fromPush(push);
      if (notification != null && mounted) openNotification(context, ref, notification);
    });
  }

  @override
  void dispose() {
    _taps?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(pushRegistrationProvider); // once per login
    final unread = ref.watch(unreadNotificationCountProvider);
    return IconButton(
      tooltip: AppStrings.notifications,
      icon: Badge(
        isLabelVisible: unread > 0,
        label: Text(unread > 9 ? '9+' : '$unread'),
        child: Icon(unread > 0 ? Icons.notifications : Icons.notifications_outlined),
      ),
      onPressed: () => context.push(Routes.notifications),
    );
  }
}
