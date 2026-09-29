import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/models/app_notification.dart';
import '../data/notification_repository.dart';

// Riverpod providers: the logged-in user's notifications and how many are unread.
// Screens watch these; these call the repositories in ../data/.

/// The bell and the Notifications screen. Live: new ones appear by themselves.
final myNotificationsProvider = StreamProvider.autoDispose<List<AppNotification>>(
    (ref) => ref.watch(notificationRepositoryProvider).watchMine());

/// The number on the bell. 0 while loading, or if the list can't be loaded.
final unreadNotificationCountProvider = Provider.autoDispose<int>((ref) =>
    ref.watch(myNotificationsProvider).valueOrNull?.where((n) => !n.isRead).length ?? 0);
