import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/constants/app_images.dart';
import '../../../core/router/route_names.dart';
import '../../../core/strings/app_strings.dart';
import '../../../core/theme/app_colors.dart';
import '../providers/auth_providers.dart';
import '../widgets/dzong_hero.dart';

/// A2 Welcome
/// Purpose: Logging in comes first, for everyone with an account; below it,
/// new users choose customer or worker (that starts their sign-up). Anyone can
/// browse sports grounds without an account.
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

    final text = Theme.of(context).textTheme;
    final sectionLabel = text.titleSmall?.copyWith(fontWeight: FontWeight.w700, color: AppColors.inkSoft);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      // White status bar icons on the roof.
      value: SystemUiOverlayStyle.light.copyWith(statusBarColor: Colors.transparent),
      child: Scaffold(
        // Fills the screen, but scrolls on small phones or with large text.
        body: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            physics: const ClampingScrollPhysics(),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: IntrinsicHeight(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // The roof takes whatever room the buttons leave.
                    Expanded(
                      child: DzongHero(
                        child: SafeArea(
                          bottom: false,
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(24, 28, 24, 0),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const _LogoCard(),
                                const SizedBox(height: 22),
                                Text(
                                  AppStrings.tagline,
                                  textAlign: TextAlign.center,
                                  style: text.titleMedium?.copyWith(color: Colors.white, fontWeight: FontWeight.w600),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    SafeArea(
                      top: false,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(24, 4, 24, 24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // Everyone with an account logs in, whatever they use the app for.
                            Text(AppStrings.alreadyHaveAccount, style: sectionLabel),
                            const SizedBox(height: 12),
                            FilledButton(
                              style: FilledButton.styleFrom(
                                elevation: 3,
                                shadowColor: AppColors.primaryDeep.withValues(alpha: 0.5),
                              ),
                              onPressed: () => continueAs(null),
                              child: const Text(AppStrings.logIn),
                            ),
                            const Divider(height: 44),
                            // New users pick how they'll use the app; that is their sign-up.
                            Text(AppStrings.newToKuzuHelp, style: sectionLabel),
                            const SizedBox(height: 12),
                            _RoleButton(
                              icon: Icons.search_rounded,
                              title: AppStrings.needService,
                              hint: AppStrings.needServiceHint,
                              onPressed: () => continueAs(UserRole.customer),
                            ),
                            const SizedBox(height: 12),
                            _RoleButton(
                              icon: Icons.handyman_outlined,
                              title: AppStrings.offerService,
                              hint: AppStrings.offerServiceHint,
                              onPressed: () => continueAs(UserRole.worker),
                            ),
                            const Divider(height: 44),
                            // Sports grounds are open to everyone; booking asks them to log in.
                            Text(AppStrings.lookingForGround, style: sectionLabel),
                            const SizedBox(height: 12),
                            _RoleButton(
                              icon: Icons.sports_soccer_rounded,
                              title: AppStrings.browseGrounds,
                              hint: AppStrings.browseGroundsHint,
                              onPressed: () => context.push(Routes.grounds),
                            ),
                          ],
                        ),
                      ),
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

/// The logo, mark over name, on a white card floating on the roof.
class _LogoCard extends StatelessWidget {
  const _LogoCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(30, 22, 30, 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.22), blurRadius: 32, offset: const Offset(0, 14)),
        ],
      ),
      child: Semantics(
        label: AppStrings.appName,
        image: true,
        excludeSemantics: true,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset(AppImages.mark, height: 74),
            const SizedBox(height: 12),
            Image.asset(AppImages.wordmark, height: 28),
          ],
        ),
      ),
    );
  }
}

/// White card button for signing up: an icon on a tile, a title, a one-line
/// hint and an arrow.
class _RoleButton extends StatelessWidget {
  final IconData icon;
  final String title;
  final String hint;
  final VoidCallback onPressed;

  const _RoleButton({required this.icon, required this.title, required this.hint, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        padding: const EdgeInsets.symmetric(horizontal: 14),
        foregroundColor: AppColors.ink,
        side: const BorderSide(color: AppColors.line, width: 1.2),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(color: AppColors.peach, borderRadius: BorderRadius.circular(14)),
              child: Icon(icon, size: 24, color: AppColors.primaryDeep),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, letterSpacing: -0.3)),
                  const SizedBox(height: 2),
                  Text(
                    hint,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      height: 1.35,
                      color: AppColors.muted,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.arrow_forward_rounded, color: AppColors.primaryDeep),
          ],
        ),
      ),
    );
  }
}
