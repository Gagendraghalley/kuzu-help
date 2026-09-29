import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/route_names.dart';
import '../../../core/strings/app_strings.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/app_bar_logo.dart';
import '../../../shared/widgets/async_view.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/info_note.dart';
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
                    padding: const EdgeInsets.all(20),
                    children: [
                      Text(
                        AppStrings.greeting(name),
                        style: text.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Text(AppStrings.whatDoYouNeed, style: text.bodyLarge),
                      const SizedBox(height: 16),
                      // Looks like a search box; the search itself is its own screen.
                      Semantics(
                        button: true,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: () => context.push(Routes.searchWorkers),
                          child: InputDecorator(
                            decoration: const InputDecoration(prefixIcon: Icon(Icons.search)),
                            child: Text(AppStrings.searchWorkers,
                                style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Row(
                        children: [
                          Expanded(
                            child: _Shortcut(
                              icon: Icons.favorite_border,
                              label: AppStrings.savedWorkers,
                              route: Routes.savedWorkers,
                            ),
                          ),
                          SizedBox(width: 12),
                          Expanded(
                            child: _Shortcut(
                              icon: Icons.assignment_outlined,
                              label: AppStrings.myJobRequests,
                              route: Routes.jobs,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          Text(AppStrings.yourArea, style: text.labelLarge),
                          const SizedBox(width: 12),
                          const Flexible(child: DzongkhagSelector()),
                        ],
                      ),
                      const SizedBox(height: 20),
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
  final String label;
  final String route;

  const _Shortcut({required this.icon, required this.label, required this.route});

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push(route),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          child: Row(
            children: [
              Icon(icon, color: AppColors.primaryDeep),
              const SizedBox(width: 8),
              Expanded(child: Text(label, style: const TextStyle(fontWeight: FontWeight.w600))),
            ],
          ),
        ),
      ),
    );
  }
}
