import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/strings/app_strings.dart';
import '../providers/auth_providers.dart';

/// App bar button that logs out; the router then shows Welcome.
/// Used where Settings (D1) isn't offered: set password (A5) and worker setup (B1).
class LogoutButton extends ConsumerWidget {
  const LogoutButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return IconButton(
      icon: const Icon(Icons.logout),
      tooltip: AppStrings.logout,
      onPressed: () => ref.read(authActionsProvider).signOut(),
    );
  }
}
