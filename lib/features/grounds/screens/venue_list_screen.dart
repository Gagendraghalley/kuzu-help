import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/constants/dzongkhags.dart';
import '../../../core/router/route_names.dart';
import '../../../core/strings/app_strings.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/error_messages.dart';
import '../../../shared/models/venue.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/error_view.dart';
import '../../../shared/widgets/icon_tile.dart';
import '../../../shared/widgets/info_note.dart';
import '../../../shared/widgets/loading_view.dart';
import '../../../shared/widgets/section_header.dart';
import '../../auth/data/auth_repository.dart';
import '../../customer/providers/search_providers.dart';
import '../../customer/widgets/dzongkhag_selector.dart';
import '../providers/booking_providers.dart';
import '../providers/venue_providers.dart';
import '../widgets/venue_card.dart';

/// Sports grounds, on their own screen (workers, whose home is their
/// dashboard, and visitors from Welcome who haven't logged in). Customers see
/// the same list on Customer Home, and players on theirs (PlayerHomeScreen).
class VenueListScreen extends ConsumerWidget {
  const VenueListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text(AppStrings.sportsGrounds)),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () => Future.wait([ref.refresh(venuesProvider.future), ref.refresh(myBookingsProvider.future)]),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
            children: const [SportsGroundsSection()],
          ),
        ),
      ),
    );
  }
}

/// Venues in the chosen dzongkhag, which can be narrowed to one sport, and
/// the way to My bookings (once logged in). Not scrollable itself: it sits in a list.
class SportsGroundsSection extends ConsumerWidget {
  const SportsGroundsSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final venues = ref.watch(venuesProvider);
    final loggedIn = ref.watch(authRepositoryProvider).isLoggedIn;
    final text = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (loggedIn) ...[
          const _MyBookingsCard(),
          const SizedBox(height: 28),
        ],
        const SectionHeader(AppStrings.sportsGrounds),
        const SizedBox(height: 10),
        Row(
          children: [
            Text(AppStrings.yourArea, style: text.labelLarge?.copyWith(color: AppColors.muted)),
            const SizedBox(width: 12),
            const Flexible(child: DzongkhagSelector()),
          ],
        ),
        const SizedBox(height: 16),
        venues.when(
          loading: () => const Padding(padding: EdgeInsets.all(32), child: LoadingView()),
          error: (e, _) => ErrorView(message: ErrorMessages.from(e), onRetry: () => ref.invalidate(venuesProvider)),
          data: (venues) => _VenueResults(venues: venues),
        ),
        const SizedBox(height: 8),
        const InfoNote(
          icon: Icons.verified_user_outlined,
          iconColor: AppColors.verified,
          text: AppStrings.venuesCheckedNote,
        ),
      ],
    );
  }
}

class _VenueResults extends ConsumerWidget {
  final List<Venue> venues;

  const _VenueResults({required this.venues});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sport = ref.watch(sportFilterProvider);
    final everywhere = ref.watch(selectedDzongkhagProvider).valueOrNull == kAllDzongkhags;
    // Only the sports these venues have, in the usual order.
    final sports = [for (final s in Sport.all) if (venues.any((v) => v.sports.contains(s))) s];
    final shown = sport == null ? venues : venues.where((v) => v.sports.contains(sport)).toList();

    void select(String? choice) => ref.read(sportFilterProvider.notifier).state = choice;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (sports.length > 1 || sport != null) ...[
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ChoiceChip(
                label: const Text(AppStrings.allSports),
                selected: sport == null,
                onSelected: (_) => select(null),
              ),
              for (final s in {...sports, if (sport != null) sport})
                ChoiceChip(
                  label: Text(AppStrings.sportLabel(s)),
                  selected: sport == s,
                  onSelected: (_) => select(sport == s ? null : s),
                ),
            ],
          ),
          const SizedBox(height: 16),
        ],
        if (shown.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: EmptyState(
              icon: Icons.sports_soccer_rounded,
              message: sport != null && venues.isNotEmpty
                  ? AppStrings.noVenuesForSport(sport)
                  : AppStrings.noVenuesYet(everywhere: everywhere),
            ),
          )
        else
          for (final venue in shown) ...[
            VenueCard(venue: venue, onTap: () => context.push(Routes.venueDetailsFor(venue.id))),
            const SizedBox(height: 12),
          ],
      ],
    );
  }
}

/// The customer's bookings, with how many are still to come.
class _MyBookingsCard extends ConsumerWidget {
  const _MyBookingsCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final upcoming = ref.watch(myBookingsProvider).valueOrNull?.where((b) => b.isUpcoming()).length ?? 0;
    return Card(
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        leading: Badge(
          isLabelVisible: upcoming > 0,
          backgroundColor: AppColors.primaryDeep,
          label: Text('$upcoming'),
          child: const IconTile(icon: Icons.event_available_rounded, size: 44),
        ),
        title: const Text(AppStrings.myBookings, style: TextStyle(fontWeight: FontWeight.w700)),
        trailing: const Icon(Icons.chevron_right_rounded, color: AppColors.muted),
        onTap: () => context.push(Routes.myBookings),
      ),
    );
  }
}
