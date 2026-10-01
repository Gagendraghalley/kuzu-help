import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/router/route_names.dart';
import '../../../core/strings/app_strings.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/app_bar_logo.dart';
import '../../../shared/widgets/brand_panel.dart';
import '../../../shared/widgets/icon_tile.dart';
import '../../../shared/widgets/section_header.dart';
import '../providers/auth_providers.dart';

/// A2 Welcome
/// Purpose: What people come to do comes first: find a service (signs up a
/// customer), book a ground (browsing needs no account) or, for workers,
/// offer a service (signs up a worker). Logging in, for everyone with an
/// account, closes the page.
/// Layout: the logo, a brand panel that says what the app is, the three
/// choices as one list, and Log in at the foot, as on the home screens.
/// Backend: None; remembers the chosen role for sign-up.
/// Done when: Each choice opens sign-up with its role, or the grounds; Log in
/// opens login.
class WelcomeScreen extends ConsumerWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    void continueAs(String? role) {
      ref.read(chosenRoleProvider.notifier).state = role;
      context.push(Routes.login);
    }

    final text = Theme.of(context).textTheme;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      // Dark status bar icons on the light screen.
      value: SystemUiOverlayStyle.dark.copyWith(statusBarColor: Colors.transparent),
      child: Scaffold(
        body: SafeArea(
          // Fills the screen, with Log in at the foot, but scrolls on small
          // phones or with large text.
          child: LayoutBuilder(
            builder: (context, constraints) => SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight - 28),
                child: IntrinsicHeight(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(
                        height: kToolbarHeight,
                        child: Align(alignment: Alignment.centerLeft, child: AppBarLogo()),
                      ),
                      const SizedBox(height: 12),
                      BrandPanel(
                        padding: const EdgeInsets.fromLTRB(22, 26, 22, 24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Semantics(
                              header: true,
                              child: Text(
                                AppStrings.welcomeTitle,
                                style: text.headlineSmall?.copyWith(color: Colors.white, fontSize: 26, height: 1.2),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              AppStrings.tagline,
                              style: text.bodyLarge?.copyWith(
                                color: Colors.white.withValues(alpha: 0.92),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 18),
                            // Why it can be trusted: workers are approved by
                            // admins, and only customers who got in touch review.
                            const Wrap(
                              spacing: 18,
                              runSpacing: 8,
                              children: [
                                _TrustPoint(icon: Icons.verified_outlined, label: AppStrings.trustVerified),
                                _TrustPoint(icon: Icons.star_outline_rounded, label: AppStrings.trustReviews),
                                _TrustPoint(icon: Icons.place_outlined, label: AppStrings.trustNearby),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 28),
                      const SectionHeader(AppStrings.whatToDo),
                      const SizedBox(height: 12),
                      // The three ways in, one list.
                      Card(
                        child: Column(
                          children: [
                            _ChoiceRow(
                              icon: Icons.search_rounded,
                              title: AppStrings.needService,
                              hint: AppStrings.needServiceHint,
                              onTap: () => continueAs(UserRole.customer), // signs up
                            ),
                            const Divider(indent: 76),
                            _ChoiceRow(
                              icon: Icons.sports_soccer_rounded,
                              title: AppStrings.browseGrounds,
                              hint: AppStrings.browseGroundsHint,
                              // Open to everyone; booking asks them to log in.
                              onTap: () => context.push(Routes.grounds),
                            ),
                            const Divider(indent: 76),
                            _ChoiceRow(
                              icon: Icons.handyman_outlined,
                              title: AppStrings.offerService,
                              hint: AppStrings.offerServiceHint,
                              onTap: () => continueAs(UserRole.worker), // signs up
                            ),
                          ],
                        ),
                      ),
                      const Spacer(),
                      const SizedBox(height: 28),
                      // Everyone with an account logs in, whatever they use the app for.
                      Text(
                        AppStrings.alreadyHaveAccount,
                        textAlign: TextAlign.center,
                        style: text.bodyMedium?.copyWith(color: AppColors.muted),
                      ),
                      const SizedBox(height: 10),
                      OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size.fromHeight(54),
                          backgroundColor: Colors.white,
                          foregroundColor: AppColors.primaryDeep,
                          side: const BorderSide(color: AppColors.outline, width: 1.2),
                        ),
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
      ),
    );
  }
}

/// A small white icon and [label], on the brand panel.
class _TrustPoint extends StatelessWidget {
  final IconData icon;
  final String label;

  const _TrustPoint({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 17, color: Colors.white),
        const SizedBox(width: 6),
        Text(
          label,
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: Colors.white,
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
              ),
        ),
      ],
    );
  }
}

/// One choice in the list: its icon on a tinted tile, a title and a short
/// hint, and a chevron.
class _ChoiceRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String hint;
  final VoidCallback onTap;

  const _ChoiceRow({required this.icon, required this.title, required this.hint, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 12, 16),
        child: Row(
          children: [
            IconTile(icon: icon, size: 44),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontSize: 16.5, fontWeight: FontWeight.w700, letterSpacing: -0.2)),
                  const SizedBox(height: 2),
                  Text(
                    hint,
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, height: 1.35, color: AppColors.muted),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.chevron_right_rounded, color: AppColors.muted),
          ],
        ),
      ),
    );
  }
}
