import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/route_names.dart';
import '../../../core/strings/app_strings.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/async_view.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../grounds/providers/venue_providers.dart';
import '../../grounds/widgets/status_pill.dart';
import '../../grounds/widgets/venue_card.dart';
import '../widgets/billing_settings_sheet.dart';

/// Admin: every sports venue, with who runs it and its subscription. Admins
/// register a venue together with its manager; tapping one opens it to run
/// like its manager does, with the manager's card on top. Billing settings
/// (the app bar) holds the fee for new grounds and how managers pay.
class AdminVenuesScreen extends ConsumerWidget {
  const AdminVenuesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final venues = ref.watch(allVenuesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text(AppStrings.sportsVenues),
        actions: [
          IconButton(
            tooltip: AppStrings.billingSettings,
            icon: const Icon(Icons.receipt_long_outlined),
            onPressed: () => openBillingSettings(context, ref),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.add_rounded),
        label: const Text(AppStrings.addVenue),
        onPressed: () => context.push(Routes.addVenue),
      ),
      body: SafeArea(
        child: AsyncView(
          value: venues,
          onRetry: () => ref.invalidate(allVenuesProvider),
          data: (venues) => RefreshIndicator(
            onRefresh: () => ref.refresh(allVenuesProvider.future),
            child: venues.isEmpty
                ? ListView(
                    // Scrollable, so pull-to-refresh still works.
                    children: const [
                      SizedBox(height: 120),
                      EmptyState(icon: Icons.stadium_outlined, message: AppStrings.noVenuesAdded),
                    ],
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
                    itemCount: venues.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, i) {
                      final venue = venues[i];
                      return VenueCard(
                        venue: venue,
                        status: Wrap(
                          spacing: 8,
                          runSpacing: 6,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            VenueStatusPill(venue: venue),
                            if (venue.subscription case final subscription?) SubscriptionPill(subscription: subscription),
                            if (venue.managerName case final name? when name.trim().isNotEmpty)
                              Text(name, style: const TextStyle(color: AppColors.inkSoft, fontWeight: FontWeight.w600)),
                          ],
                        ),
                        onTap: () => context.push(Routes.venueManageFor(venue.id)),
                      );
                    },
                  ),
          ),
        ),
      ),
    );
  }
}
