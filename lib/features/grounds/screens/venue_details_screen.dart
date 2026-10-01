import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/location/location_service.dart';
import '../../../core/location/my_position.dart';
import '../../../core/router/route_names.dart';
import '../../../core/strings/app_strings.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/launcher_utils.dart';
import '../../../shared/models/ground.dart';
import '../../../shared/models/venue.dart';
import '../../../shared/models/venue_review.dart';
import '../../../shared/widgets/async_view.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/icon_tile.dart';
import '../../../shared/widgets/info_note.dart';
import '../../../shared/widgets/location_problem.dart';
import '../../../shared/widgets/section_header.dart';
import '../../../shared/widgets/star_rating.dart';
import '../../admin/providers/admin_providers.dart';
import '../../auth/data/auth_repository.dart';
import '../data/venue_repository.dart';
import '../providers/booking_providers.dart';
import '../providers/venue_providers.dart';
import '../widgets/status_pill.dart';
import '../widgets/venue_card.dart';
import '../widgets/week_timings.dart';

/// A venue's page
/// Purpose: Show customers the grounds, prices, each day's hours and reviews,
/// so they can choose a ground and book it, or call the venue; how far away
/// it is and directions in Google Maps, once it's on the map. Visitors who
/// haven't logged in see all of it too.
/// Backend: Reads venue_directory (or venues, for its manager and admins),
/// grounds with their opening hours, and venue_reviews.
/// Done when: 'Book' opens the booking screen for that ground. The venue's
/// manager sees its page as customers do, without booking; admins also get a
/// way to run it.
class VenueDetailsScreen extends ConsumerWidget {
  final String venueId;

  const VenueDetailsScreen({super.key, required this.venueId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final details = ref.watch(venueDetailsProvider(venueId));
    final venue = details.valueOrNull?.venue;
    final isManager = venue != null && venue.managerId == ref.watch(authRepositoryProvider).userId;

    return Scaffold(
      appBar: AppBar(),
      body: AsyncView(
        value: details,
        onRetry: () => ref.invalidate(venueDetailsProvider(venueId)),
        data: (details) => details == null
            ? const EmptyState(icon: Icons.sports_soccer_rounded, message: AppStrings.venueNotListed)
            : _VenuePage(details: details, isManager: isManager),
      ),
      bottomNavigationBar: venue == null || isManager
          ? null
          : DecoratedBox(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                boxShadow: [
                  BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 24, offset: const Offset(0, -6)),
                ],
              ),
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
                  child: _ContactButtons(venue: venue),
                ),
              ),
            ),
    );
  }
}

class _VenuePage extends ConsumerWidget {
  final VenueDetails details;
  final bool isManager;

  const _VenuePage({required this.details, required this.isManager});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final venue = details.venue;
    final isAdmin = ref.watch(isAdminProvider);
    // Its type, price and timings; none until they're added (only its manager and admins see it then).
    final ground = details.grounds.firstOrNull;
    final about = venue.description?.trim() ?? '';
    final policy = venue.cancellationPolicy?.trim() ?? '';
    final text = Theme.of(context).textTheme;

    return RefreshIndicator(
      onRefresh: () => Future.wait([
        ref.refresh(venueDetailsProvider(venue.id).future),
        ref.refresh(venueReviewsProvider(venue.id).future),
      ]),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          if (isManager) ...[
            const InfoNote(icon: Icons.visibility_outlined, text: AppStrings.yourPublicVenue),
            const SizedBox(height: 16),
          ] else if (isAdmin) ...[
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(52)),
              icon: const Icon(Icons.manage_accounts_outlined),
              label: const Text(AppStrings.manageVenue),
              onPressed: () => context.push(Routes.venueManageFor(venue.id)),
            ),
            const SizedBox(height: 16),
          ],
          _Header(venue: venue, showStatus: isManager || isAdmin),
          if (about.isNotEmpty) ...[
            const SizedBox(height: 28),
            const SectionHeader(AppStrings.about),
            const SizedBox(height: 10),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(about, style: text.bodyLarge?.copyWith(color: AppColors.inkSoft)),
              ),
            ),
          ],
          const SizedBox(height: 28),
          const SectionHeader(AppStrings.timings),
          const SizedBox(height: 10),
          if (ground == null)
            const InfoNote(icon: Icons.schedule_rounded, text: AppStrings.noTimingsYet)
          else
            _GroundCard(
              ground: ground,
              // Only customers book, and only listed grounds with timings.
              onBook: !isManager && venue.isListed && ground.isActive && ground.slots.isNotEmpty
                  ? () => context.push(Routes.bookGroundFor(venue.id, ground.id))
                  : null,
            ),
          const SizedBox(height: 28),
          const SectionHeader(AppStrings.cancelling),
          const SizedBox(height: 10),
          InfoNote(
            icon: Icons.event_busy_outlined,
            text: [
              AppStrings.freeCancelNote(venue.freeCancelHours),
              if (policy.isNotEmpty) policy,
              venue.autoConfirm ? AppStrings.confirmedAtOnce : AppStrings.confirmedByVenue,
            ].join('\n\n'),
          ),
          const SizedBox(height: 28),
          _Reviews(
            venue: venue,
            isCustomer: ref.watch(authRepositoryProvider).isLoggedIn && !isManager && !isAdmin,
          ),
        ],
      ),
    );
  }
}

class _Header extends ConsumerWidget {
  final Venue venue;
  final bool showStatus; // the manager and admins see where it stands

  const _Header({required this.venue, required this.showStatus});

  /// Finds the phone, asking to use its location the first time.
  Future<void> _locate(BuildContext context, WidgetRef ref) async {
    try {
      await ref.read(myPositionProvider.notifier).locate();
    } on LocationUnavailable catch (e) {
      if (context.mounted) showLocationProblem(context, ref.read(locationServiceProvider), e.problem);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    final place = venue.coordinates;
    final position = ref.watch(myPositionProvider);
    final here = position.valueOrNull;

    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          VenueCover(url: venue.coverUrl, height: 180),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(venue.name, style: text.headlineSmall),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Icon(Icons.location_on_outlined, size: 18, color: muted),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        [venue.address, venue.location]
                            .where((part) => part != null && part.trim().isNotEmpty)
                            .join(', '),
                        style: TextStyle(color: muted),
                      ),
                    ),
                  ],
                ),
                if (place != null) ...[
                  const SizedBox(height: 4),
                  if (here != null)
                    Row(
                      children: [
                        const Icon(Icons.near_me_rounded, size: 18, color: AppColors.primaryDeep),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            AppStrings.distanceFromYou(here.distanceKm(place)),
                            style: const TextStyle(color: AppColors.primaryDeep, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    )
                  else
                    // The phone's place isn't known yet: asks to use it, here where it's wanted.
                    TextButton.icon(
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        visualDensity: VisualDensity.compact,
                      ),
                      icon: position.isLoading
                          ? const SizedBox.square(dimension: 16, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.near_me_rounded, size: 18),
                      label: const Text(AppStrings.showDistance),
                      onPressed: position.isLoading ? null : () => _locate(context, ref),
                    ),
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.directions_rounded),
                    label: const Text(AppStrings.directions),
                    onPressed: () => openDirections(context, place),
                  ),
                ],
                const SizedBox(height: 10),
                Row(
                  children: [
                    StarRating(rating: venue.avgRating),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        venue.reviewCount == 0 ? AppStrings.noReviewsShort : AppStrings.reviewCount(venue.reviewCount),
                        style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.inkSoft),
                      ),
                    ),
                  ],
                ),
                if (showStatus || venue.autoConfirm) ...[
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      if (showStatus) VenueStatusPill(venue: venue),
                      if (venue.autoConfirm) const StatusPill(label: AppStrings.instantBooking, color: AppColors.verified),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The ground's type and surface, price, the week's timings, and 'Book'.
class _GroundCard extends StatelessWidget {
  final Ground ground;
  final VoidCallback? onBook;

  const _GroundCard({required this.ground, required this.onBook});

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final details = [
      AppStrings.sportLabel(ground.sport),
      if (ground.format case final format? when format.trim().isNotEmpty) format,
      if (ground.surface case final surface? when surface.trim().isNotEmpty) surface,
      ground.isIndoor ? AppStrings.indoor : AppStrings.outdoor,
      if (ground.hasFloodlights) AppStrings.floodlights,
    ];
    final onBook = this.onBook;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                IconTile(icon: _sportIcon(ground.sport), size: 44),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(details.join(' · '),
                      style: text.titleSmall?.copyWith(fontWeight: FontWeight.w700, color: AppColors.inkSoft)),
                ),
                if (!ground.isActive) const StatusPill(label: AppStrings.paused, color: AppColors.unavailable),
              ],
            ),
            const SizedBox(height: 14),
            // One price all day, or the day and night prices one under the other.
            Semantics(
              label: AppStrings.groundPrice(ground.pricePerHourNu,
                  eveningPrice: ground.eveningPriceNu, eveningFrom: ground.eveningFromHour),
              excludeSemantics: true,
              child: switch (ground.eveningPriceNu) {
                null => Align(alignment: Alignment.centerLeft, child: PricePerHour(ground.pricePerHourNu, size: 22)),
                final night => Column(
                    children: [
                      _PriceLine(label: AppStrings.dayPrice, price: ground.pricePerHourNu),
                      const SizedBox(height: 6),
                      _PriceLine(label: AppStrings.nightPriceFrom(ground.eveningFromHour), price: night),
                    ],
                  ),
              },
            ),
            const SizedBox(height: 14),
            if (ground.slots.isEmpty)
              const InfoNote(icon: Icons.schedule_rounded, text: AppStrings.noTimingsYet)
            else
              WeekTimings(ground: ground),
            if (onBook != null) ...[
              const SizedBox(height: 14),
              FilledButton.icon(
                icon: const Icon(Icons.event_available_rounded),
                label: const Text(AppStrings.book),
                onPressed: onBook,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// 'Night, from 6 pm ........ Nu. 1,500 /hour'
class _PriceLine extends StatelessWidget {
  final String label;
  final int price;

  const _PriceLine({required this.label, required this.price});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Expanded(
          child: Text(label, style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.inkSoft)),
        ),
        PricePerHour(price),
      ],
    );
  }
}

IconData _sportIcon(String sport) => switch (sport) {
      Sport.basketball => Icons.sports_basketball_rounded,
      Sport.badminton => Icons.sports_tennis_rounded,
      Sport.other => Icons.sports_rounded,
      _ => Icons.sports_soccer_rounded,
    };

class _Reviews extends ConsumerWidget {
  final Venue venue;
  final bool isCustomer;

  const _Reviews({required this.venue, required this.isCustomer});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reviews = ref.watch(venueReviewsProvider(venue.id));
    final canReview = isCustomer && ref.watch(canReviewVenueProvider(venue.id));
    final hasMine = canReview && ref.watch(myVenueReviewProvider(venue.id)).valueOrNull != null;
    final muted = TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeader(
          '${AppStrings.reviews} (${venue.reviewCount})',
          action: canReview
              ? TextButton.icon(
                  icon: const Icon(Icons.rate_review_outlined),
                  label: Text(hasMine ? AppStrings.editReview : AppStrings.writeReview),
                  onPressed: () => context.push(Routes.writeVenueReviewFor(venue.id)),
                )
              : null,
        ),
        if (isCustomer && !canReview) ...[
          const SizedBox(height: 8),
          const InfoNote(icon: Icons.rate_review_outlined, text: AppStrings.reviewVenueAfterPlaying),
        ],
        const SizedBox(height: 10),
        reviews.when(
          loading: () => const Padding(padding: EdgeInsets.all(16), child: Center(child: CircularProgressIndicator())),
          error: (_, __) => Row(
            children: [
              const Expanded(child: Text(AppStrings.genericError)),
              TextButton(
                onPressed: () => ref.invalidate(venueReviewsProvider(venue.id)),
                child: const Text(AppStrings.retry),
              ),
            ],
          ),
          data: (reviews) => reviews.isEmpty
              ? Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text(AppStrings.noVenueReviews, style: muted),
                )
              : Card(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      children: [
                        for (final (i, review) in reviews.indexed) ...[
                          if (i > 0) const Divider(),
                          _ReviewTile(review: review),
                        ],
                      ],
                    ),
                  ),
                ),
        ),
      ],
    );
  }
}

class _ReviewTile extends StatelessWidget {
  final VenueReview review;

  const _ReviewTile({required this.review});

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final comment = review.comment?.trim() ?? '';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              StarRating(rating: review.rating.toDouble()),
              const Spacer(),
              Text(AppStrings.shortDate(review.createdAt),
                  style: text.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
            ],
          ),
          if (comment.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(comment, style: text.bodyLarge?.copyWith(color: AppColors.inkSoft)),
          ],
        ],
      ),
    );
  }
}

/// Call the venue, or WhatsApp it when it has a number for that.
class _ContactButtons extends StatelessWidget {
  final Venue venue;

  const _ContactButtons({required this.venue});

  Future<void> _open(BuildContext context, Future<bool> Function() launch, String failMessage) async {
    bool opened;
    try {
      opened = await launch();
    } catch (_) {
      opened = false;
    }
    if (!opened && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(failMessage)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final whatsapp = venue.whatsappNumber;
    return Row(
      children: [
        Expanded(
          child: FilledButton.icon(
            icon: const Icon(Icons.call_rounded),
            label: const Text(AppStrings.call),
            onPressed: () => _open(context, () => LauncherUtils.call(venue.phone), AppStrings.cannotOpenPhone),
          ),
        ),
        if (whatsapp != null) ...[
          const SizedBox(width: 12),
          Expanded(
            child: FilledButton.icon(
              style: FilledButton.styleFrom(backgroundColor: AppColors.whatsapp),
              icon: const Icon(Icons.chat_rounded),
              label: const Text(AppStrings.whatsapp),
              onPressed: () => _open(context, () => LauncherUtils.whatsapp(whatsapp), AppStrings.cannotOpenWhatsapp),
            ),
          ),
        ],
      ],
    );
  }
}
