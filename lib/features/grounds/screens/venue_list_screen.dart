import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/constants/dzongkhags.dart';
import '../../../core/location/location_service.dart';
import '../../../core/location/my_position.dart';
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
import '../../../shared/widgets/location_problem.dart';
import '../../../shared/widgets/search_box_button.dart';
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
          onRefresh: () => refreshSportsGrounds(ref),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
            children: const [
              SearchBoxButton(hint: AppStrings.searchGrounds, route: Routes.searchGrounds, outlined: true),
              SizedBox(height: 20),
              SportsGroundsSection(),
            ],
          ),
        ),
      ),
    );
  }
}

/// Pull to refresh on a list of sports grounds: the venues, the customer's
/// bookings, and where the phone is now (it may have moved).
Future<void> refreshSportsGrounds(WidgetRef ref) {
  ref.invalidate(myPositionProvider);
  return Future.wait([ref.refresh(venuesProvider.future), ref.refresh(myBookingsProvider.future)]);
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

  /// Finds the phone, asking to use its location if need be; says why not
  /// when it can't. True once found.
  static Future<bool> _findPhone(BuildContext context, WidgetRef ref) async {
    try {
      await ref.read(myPositionProvider.notifier).locate();
      return true;
    } on LocationUnavailable catch (e) {
      if (context.mounted) showLocationProblem(context, ref.read(locationServiceProvider), e.problem);
      return false;
    }
  }

  /// Nearest first: finds the phone first, if need be.
  Future<void> _sortByDistance(BuildContext context, WidgetRef ref, bool on) async {
    if (on && ref.read(myPositionProvider).valueOrNull == null && !await _findPhone(context, ref)) return;
    ref.read(nearestFirstProvider.notifier).state = on;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sport = ref.watch(sportFilterProvider);
    final everywhere = ref.watch(selectedDzongkhagProvider).valueOrNull == kAllDzongkhags;
    final position = ref.watch(myPositionProvider);
    final here = position.valueOrNull;
    final nearestFirst = ref.watch(nearestFirstProvider) && here != null;
    // Only the sports these venues have, in the usual order.
    final sports = [for (final s in Sport.all) if (venues.any((v) => v.sports.contains(s))) s];
    final choosesSport = sports.length > 1 || sport != null;
    final onMap = venues.any((v) => v.coordinates != null);

    double? distanceTo(Venue venue) => switch ((here, venue.coordinates)) {
          (final from?, final to?) => from.distanceKm(to),
          _ => null,
        };
    final shown = sport == null ? [...venues] : venues.where((v) => v.sports.contains(sport)).toList();
    // Grounds not on the map yet go last.
    if (nearestFirst) {
      shown.sort((a, b) => (distanceTo(a) ?? double.infinity).compareTo(distanceTo(b) ?? double.infinity));
    }

    void select(String? choice) => ref.read(sportFilterProvider.notifier).state = choice;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (onMap || choosesSport) ...[
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (onMap)
                FilterChip(
                  avatar: position.isLoading
                      ? const SizedBox.square(dimension: 16, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.near_me_rounded, size: 18, color: AppColors.primaryDeep),
                  showCheckmark: false,
                  label: const Text(AppStrings.nearestFirst),
                  selected: nearestFirst,
                  onSelected: position.isLoading ? null : (on) => _sortByDistance(context, ref, on),
                ),
              if (choosesSport) ...[
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
            ],
          ),
          const SizedBox(height: 16),
        ],
        // Not allowed yet, or only once (iOS forgets that when the app closes).
        if (onMap && here == null && shown.isNotEmpty && !ref.watch(distancePromptClosedProvider)) ...[
          _DistancePrompt(
            finding: position.isLoading,
            onTap: () => _findPhone(context, ref),
            onClose: () => ref.read(distancePromptClosedProvider.notifier).state = true,
          ),
          const SizedBox(height: 12),
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
            VenueCard(
              venue: venue,
              distanceKm: distanceTo(venue),
              onTap: () => context.push(Routes.venueDetailsFor(venue.id)),
            ),
            const SizedBox(height: 12),
          ],
      ],
    );
  }
}

/// 'See how far each ground is': uses the phone's location when tapped, until
/// closed with its ✕.
class _DistancePrompt extends StatelessWidget {
  final bool finding;
  final VoidCallback onTap;
  final VoidCallback onClose;

  const _DistancePrompt({required this.finding, required this.onTap, required this.onClose});

  @override
  Widget build(BuildContext context) {
    return Card(
      color: AppColors.peach,
      child: InkWell(
        onTap: finding ? null : onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 4, 10),
          child: Row(
            children: [
              SizedBox.square(
                dimension: 24,
                child: finding
                    ? const Padding(padding: EdgeInsets.all(3), child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.near_me_rounded, color: AppColors.primaryDeep),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(AppStrings.distancePrompt, style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.ink)),
                    SizedBox(height: 2),
                    Text(AppStrings.distancePromptHint, style: TextStyle(fontSize: 13.5, color: AppColors.inkSoft)),
                  ],
                ),
              ),
              IconButton(
                tooltip: AppStrings.close,
                icon: const Icon(Icons.close_rounded, size: 20, color: AppColors.muted),
                onPressed: onClose,
              ),
            ],
          ),
        ),
      ),
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
