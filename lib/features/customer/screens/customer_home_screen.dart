import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/route_names.dart';
import '../../../core/strings/app_strings.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/app_bar_logo.dart';
import '../../../shared/widgets/async_view.dart';
import '../../../shared/widgets/brand_panel.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/icon_tile.dart';
import '../../../shared/widgets/info_note.dart';
import '../../../shared/widgets/section_header.dart';
import '../../notifications/widgets/notifications_button.dart';
import '../../profile/providers/profile_providers.dart';
import '../../profile/widgets/settings_button.dart';
import '../providers/search_providers.dart';
import '../widgets/category_grid.dart';
import '../widgets/dzongkhag_selector.dart';

/// C1 Customer home
/// Purpose: Help customers find a service quickly.
/// Backend: Reads service_categories.
/// Done when: Tapping a category opens the list for the selected dzongkhag.
class CustomerHomeScreen extends ConsumerWidget {
  const CustomerHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categories = ref.watch(categoriesProvider);
    final name = ref.watch(myProfileProvider).valueOrNull?.fullName.trim();
    final text = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: const AppBarLogo(), actions: const [NotificationsButton(), SettingsButton()]),
      body: SafeArea(
        child: AsyncView(
          value: categories,
          onRetry: () => ref.invalidate(categoriesProvider),
          data: (categories) => categories.isEmpty
              ? const EmptyState(icon: Icons.handyman_outlined, message: AppStrings.noServicesYet)
              : RefreshIndicator(
                  onRefresh: () => ref.refresh(categoriesProvider.future),
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
                    children: [
                      BrandPanel(
                        padding: const EdgeInsets.fromLTRB(20, 22, 20, 20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              AppStrings.greeting(name),
                              style: text.headlineSmall?.copyWith(color: Colors.white),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              AppStrings.whatDoYouNeed,
                              style: text.bodyLarge?.copyWith(color: Colors.white, fontWeight: FontWeight.w500),
                            ),
                            const SizedBox(height: 18),
                            // Looks like a search box; the search itself is its own screen.
                            Semantics(
                              button: true,
                              child: Material(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(16),
                                  onTap: () => context.push(Routes.searchWorkers),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                                    child: Row(
                                      children: [
                                        const Icon(Icons.search_rounded, color: AppColors.primaryDeep),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Text(
                                            AppStrings.searchWorkers,
                                            style: text.bodyLarge?.copyWith(color: AppColors.muted),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      const IntrinsicHeight(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Expanded(
                              child: _Shortcut(
                                icon: Icons.favorite_rounded,
                                color: Color(0xFFD64545),
                                label: AppStrings.savedWorkers,
                                route: Routes.savedWorkers,
                              ),
                            ),
                            SizedBox(width: 12),
                            Expanded(
                              child: _Shortcut(
                                icon: Icons.assignment_outlined,
                                color: AppColors.primaryDeep,
                                label: AppStrings.myJobRequests,
                                route: Routes.jobs,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 28),
                      const SectionHeader(AppStrings.services),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Text(AppStrings.yourArea, style: text.labelLarge?.copyWith(color: AppColors.muted)),
                          const SizedBox(width: 12),
                          const Flexible(child: DzongkhagSelector()),
                        ],
                      ),
                      const SizedBox(height: 16),
                      CategoryGrid(
                        categories: categories,
                        onTap: (category) {
                          ref.read(selectedCategoryProvider.notifier).state = category;
                          context.push(Routes.workerList);
                        },
                      ),
                      const SizedBox(height: 8),
                      const InfoNote(
                        icon: Icons.verified_user_outlined,
                        iconColor: AppColors.verified,
                        text: AppStrings.trustNote,
                      ),
                    ],
                  ),
                ),
        ),
      ),
    );
  }
}

/// A small card button under the search box.
class _Shortcut extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final String route;

  const _Shortcut({required this.icon, required this.color, required this.label, required this.route});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: () => context.push(route),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              IconTile(icon: icon, color: color, size: 40),
              const SizedBox(width: 12),
              Expanded(
                child: Text(label, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15, height: 1.3)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
