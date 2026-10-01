import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/route_names.dart';
import '../../../core/strings/app_strings.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/error_messages.dart';
import '../../../shared/widgets/app_bar_logo.dart';
import '../../../shared/widgets/brand_panel.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/error_view.dart';
import '../../../shared/widgets/icon_tile.dart';
import '../../../shared/widgets/info_note.dart';
import '../../../shared/widgets/loading_view.dart';
import '../../../shared/widgets/search_box_button.dart';
import '../../../shared/widgets/section_header.dart';
import '../../grounds/screens/venue_list_screen.dart';
import '../../notifications/widgets/notifications_button.dart';
import '../../profile/providers/profile_providers.dart';
import '../../profile/widgets/settings_button.dart';
import '../providers/search_providers.dart';
import '../widgets/category_grid.dart';
import '../widgets/dzongkhag_selector.dart';

/// The services Customer Home offers; one shows at a time.
enum HomeService { homeServices, sportsGrounds, partyDining }

/// Party & dining is hidden until it's ready; set to true to show its tile again.
const showPartyDining = false;

/// Which service Customer Home shows. Home services until the customer picks another.
final homeServiceProvider = StateProvider<HomeService>((ref) => HomeService.homeServices);

/// C1 Customer home
/// Purpose: Help customers find a service quickly: home services (workers),
/// sports grounds to book, and, soon, party and dining bookings.
/// Backend: Reads service_categories; venue_directory for sports grounds.
/// Done when: Tapping a category opens the list for the selected dzongkhag,
/// and Sports grounds lists the venues there.
class CustomerHomeScreen extends ConsumerWidget {
  const CustomerHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final service = ref.watch(homeServiceProvider);
    final name = ref.watch(myProfileProvider).valueOrNull?.fullName.trim();
    final text = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: const AppBarLogo(), actions: const [NotificationsButton(), SettingsButton()]),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () => switch (service) {
            HomeService.sportsGrounds => refreshSportsGrounds(ref),
            _ => ref.refresh(categoriesProvider.future),
          },
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
                      switch (service) {
                        HomeService.homeServices => AppStrings.whatDoYouNeed,
                        HomeService.sportsGrounds => AppStrings.bookAGround,
                        HomeService.partyDining => AppStrings.planAParty,
                      },
                      style: text.bodyLarge?.copyWith(color: Colors.white, fontWeight: FontWeight.w500),
                    ),
                    if (service == HomeService.homeServices) ...[
                      const SizedBox(height: 18),
                      const SearchBoxButton(hint: AppStrings.searchWorkers, route: Routes.searchWorkers),
                    ] else if (service == HomeService.sportsGrounds) ...[
                      const SizedBox(height: 18),
                      const SearchBoxButton(hint: AppStrings.searchGrounds, route: Routes.searchGrounds),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 16),
              const _ServicePicker(),
              const SizedBox(height: 16),
              switch (service) {
                HomeService.homeServices => const _HomeServices(),
                HomeService.sportsGrounds => const SportsGroundsSection(),
                HomeService.partyDining => const Padding(
                    padding: EdgeInsets.only(top: 16),
                    child: EmptyState(icon: Icons.celebration_outlined, message: AppStrings.partyComingSoon),
                  ),
              },
            ],
          ),
        ),
      ),
    );
  }
}

/// Big tiles: Home services, Sports grounds, and Party & dining (soon) when
/// [showPartyDining] is on.
class _ServicePicker extends ConsumerWidget {
  const _ServicePicker();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(homeServiceProvider);
    void select(HomeService service) => ref.read(homeServiceProvider.notifier).state = service;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: _ServiceTile(
              icon: Icons.handyman_rounded,
              label: AppStrings.homeServices,
              selected: selected == HomeService.homeServices,
              onTap: () => select(HomeService.homeServices),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _ServiceTile(
              icon: Icons.sports_soccer_rounded,
              label: AppStrings.sportsGrounds,
              selected: selected == HomeService.sportsGrounds,
              onTap: () => select(HomeService.sportsGrounds),
            ),
          ),
          if (showPartyDining) ...[
            const SizedBox(width: 10),
            Expanded(
              child: _ServiceTile(
                icon: Icons.celebration_rounded,
                label: AppStrings.partyDining,
                badge: AppStrings.comingSoon,
                selected: selected == HomeService.partyDining,
                onTap: () => select(HomeService.partyDining),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ServiceTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? badge;
  final bool selected;
  final VoidCallback onTap;

  const _ServiceTile({
    required this.icon,
    required this.label,
    this.badge,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final badge = this.badge;
    return Semantics(
      selected: selected,
      button: true,
      child: Card(
        color: selected ? AppColors.peach : null,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: selected ? AppColors.primaryDeep : AppColors.line, width: selected ? 1.6 : 1),
        ),
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 14, 8, 12),
            child: Column(
              children: [
                IconTile(icon: icon, size: 44),
                const SizedBox(height: 8),
                Text(
                  label,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    height: 1.25,
                    color: selected ? AppColors.maroon : AppColors.ink,
                  ),
                ),
                if (badge != null) ...[
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(color: AppColors.saffron, borderRadius: BorderRadius.circular(10)),
                    child: Text(badge,
                        style: const TextStyle(color: AppColors.ink, fontWeight: FontWeight.w700, fontSize: 12)),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The first service: saved workers, job requests, and the categories of work.
class _HomeServices extends ConsumerWidget {
  const _HomeServices();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categories = ref.watch(categoriesProvider);
    final text = Theme.of(context).textTheme;

    return categories.when(
      loading: () => const Padding(padding: EdgeInsets.all(32), child: LoadingView()),
      error: (e, _) => ErrorView(message: ErrorMessages.from(e), onRetry: () => ref.invalidate(categoriesProvider)),
      data: (categories) => categories.isEmpty
          ? const EmptyState(icon: Icons.handyman_outlined, message: AppStrings.noServicesYet)
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
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
