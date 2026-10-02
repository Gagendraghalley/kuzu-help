import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/route_names.dart';
import '../../../core/strings/app_strings.dart';
import '../../../shared/widgets/app_bar_logo.dart';
import '../../../shared/widgets/async_view.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../notifications/widgets/notifications_button.dart';
import '../../profile/widgets/settings_button.dart';
import '../providers/venue_providers.dart';
import '../widgets/status_pill.dart';
import '../widgets/venue_card.dart';
import 'venue_manage_screen.dart';

/// Venue manager's home
/// Purpose: The first screen of the person who runs a venue: their venue,
/// ready to run, with the bell and Settings like the other home screens.
/// Someone who runs more than one picks one first.
/// Backend: Reads the venues they manage.
/// Done when: A new booking request is one tap away.
class ManagerHomeScreen extends ConsumerWidget {
  const ManagerHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final venues = ref.watch(myVenuesProvider);

    return Scaffold(
      appBar: AppBar(title: const AppBarLogo(), actions: const [NotificationsButton(), SettingsButton()]),
      body: SafeArea(
        child: AsyncView(
          value: venues,
          onRetry: () => ref.invalidate(myVenuesProvider),
          data: (venues) => switch (venues) {
            [] => const EmptyState(icon: Icons.stadium_outlined, message: AppStrings.noVenueToManage),
            [final venue] => VenueManagePanel(venueId: venue.id),
            _ => RefreshIndicator(
                onRefresh: () => ref.refresh(myVenuesProvider.future),
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
                  itemCount: venues.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, i) => VenueCard(
                    venue: venues[i],
                    status: Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        VenueStatusPill(venue: venues[i]),
                        if (venues[i].subscription case final subscription?) SubscriptionPill(subscription: subscription),
                      ],
                    ),
                    onTap: () => context.push(Routes.venueManageFor(venues[i].id)),
                  ),
                ),
              ),
          },
        ),
      ),
    );
  }
}
