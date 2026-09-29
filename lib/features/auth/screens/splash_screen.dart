import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_images.dart';
import '../../../core/strings/app_strings.dart';
import '../../../core/utils/error_messages.dart';
import '../../../shared/widgets/error_view.dart';
import '../providers/auth_providers.dart';

/// A1 Splash
/// Purpose: Decide where to send the user when the app opens.
/// Backend: Checks for a session; reads the user's role from profiles.
/// Done when: Each user type lands on the correct screen.
class SplashScreen extends ConsumerWidget {
  const SplashScreen({super.key});

  /// Same size and white background as the native launch screens
  /// (ios/ LaunchImage, android/ launch_logo), so nothing jumps when Flutter starts.
  static const logoSize = 240.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen(startRouteProvider, (_, next) {
      if (next is AsyncData<String>) context.go(next.value);
    });
    final start = ref.watch(startRouteProvider);

    return Scaffold(
      backgroundColor: Colors.white,
      body: start.hasError && !start.isLoading
          ? SafeArea(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ErrorView(
                    message: ErrorMessages.from(start.error!),
                    onRetry: () => ref.invalidate(startRouteProvider),
                  ),
                  // A way out if the problem is with this account.
                  TextButton(
                    onPressed: () async {
                      await ref.read(authActionsProvider).signOut();
                      ref.invalidate(startRouteProvider);
                    },
                    child: const Text(AppStrings.logout),
                  ),
                ],
              ),
            )
          : Center(
              child: Image.asset(
                AppImages.logoStacked,
                width: logoSize,
                semanticLabel: AppStrings.appName,
              ),
            ),
    );
  }
}
