import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/constants/app_images.dart';
import '../../../core/router/route_names.dart';
import '../../../core/strings/app_strings.dart';
import '../providers/auth_providers.dart';

/// A2 Welcome
/// Purpose: New users choose customer or worker (that starts their sign-up);
/// everyone else logs in.
/// Backend: None; remembers the chosen role for sign-up.
/// Done when: Either button opens login with the role remembered.
class WelcomeScreen extends ConsumerWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    void continueAs(String? role) {
      ref.read(chosenRoleProvider.notifier).state = role;
      context.push(Routes.login);
    }

    return Scaffold(
      body: SafeArea(
        // Fills the screen, but scrolls on small phones or with large text.
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight - 48),
              child: IntrinsicHeight(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Spacer(),
                    Image.asset(AppImages.logoStacked, height: 200, semanticLabel: AppStrings.appName),
                    Text(
                      AppStrings.tagline,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const Spacer(),
                    const SizedBox(height: 24),
                    // New users pick how they'll use the app; that is their sign-up.
                    Text(
                      AppStrings.newToKuzuHelp,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),
                    _RoleButton(
                      icon: Icons.search,
                      title: AppStrings.needService,
                      hint: AppStrings.needServiceHint,
                      filled: true,
                      onPressed: () => continueAs(UserRole.customer),
                    ),
                    const SizedBox(height: 12),
                    _RoleButton(
                      icon: Icons.handyman_outlined,
                      title: AppStrings.offerService,
                      hint: AppStrings.offerServiceHint,
                      onPressed: () => continueAs(UserRole.worker),
                    ),
                    // Everyone else logs in, whatever they use the app for.
                    const Divider(height: 48),
                    Text(AppStrings.alreadyHaveAccount, textAlign: TextAlign.center),
                    const SizedBox(height: 8),
                    FilledButton.tonal(
                      onPressed: () => continueAs(null),
                      child: const Text(AppStrings.logIn),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Big button with an icon, a title and a one-line hint.
class _RoleButton extends StatelessWidget {
  final IconData icon;
  final String title;
  final String hint;
  final bool filled;
  final VoidCallback onPressed;

  const _RoleButton({
    required this.icon,
    required this.title,
    required this.hint,
    required this.onPressed,
    this.filled = false,
  });

  @override
  Widget build(BuildContext context) {
    final content = Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Row(
        children: [
          Icon(icon, size: 32),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 2),
                Text(hint, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.normal)),
              ],
            ),
          ),
        ],
      ),
    );
    final shape = RoundedRectangleBorder(borderRadius: BorderRadius.circular(16));

    return filled
        ? FilledButton(
            onPressed: onPressed,
            style: FilledButton.styleFrom(shape: shape),
            child: content,
          )
        : OutlinedButton(
            onPressed: onPressed,
            style: OutlinedButton.styleFrom(
              shape: shape,
              side: BorderSide(color: Theme.of(context).colorScheme.primary, width: 2),
            ),
            child: content,
          );
  }
}
