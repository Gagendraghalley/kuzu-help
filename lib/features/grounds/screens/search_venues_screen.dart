import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/location/my_position.dart';
import '../../../core/router/route_names.dart';
import '../../../core/strings/app_strings.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/async_view.dart';
import '../../../shared/widgets/empty_state.dart';
import '../providers/venue_providers.dart';
import '../widgets/venue_card.dart';

/// Search grounds (from Customer Home): listed sports venues anywhere in
/// Bhutan whose name, town or dzongkhag contains what's typed, best rated
/// first, with how far away each is once the phone's place is known.
class SearchVenuesScreen extends ConsumerWidget {
  const SearchVenuesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final query = ref.watch(venueSearchProvider).trim();
    final results = ref.watch(venueSearchResultsProvider);
    final here = ref.watch(myPositionProvider).valueOrNull;

    return Scaffold(
      appBar: AppBar(
        centerTitle: false,
        titleSpacing: 0,
        title: Padding(
          padding: const EdgeInsets.only(right: 16),
          child: TextField(
            autofocus: true,
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              hintText: AppStrings.searchGrounds,
              isDense: true,
              prefixIcon: const Icon(Icons.search_rounded),
              contentPadding: const EdgeInsets.symmetric(vertical: 12),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: AppColors.line),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: AppColors.primaryDeep, width: 1.6),
              ),
            ),
            onChanged: (text) => ref.read(venueSearchProvider.notifier).state = text,
          ),
        ),
      ),
      body: SafeArea(
        child: query.length < 2
            ? const EmptyState(icon: Icons.search, message: AppStrings.typeToSearchGrounds)
            : AsyncView(
                value: results,
                onRetry: () => ref.invalidate(venueSearchResultsProvider),
                data: (venues) => venues.isEmpty
                    ? EmptyState(icon: Icons.sports_soccer_rounded, message: AppStrings.noVenuesNamed(query))
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                        itemCount: venues.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 12),
                        itemBuilder: (context, i) => VenueCard(
                          venue: venues[i],
                          distanceKm: switch ((here, venues[i].coordinates)) {
                            (final from?, final to?) => from.distanceKm(to),
                            _ => null,
                          },
                          onTap: () => context.push(Routes.venueDetailsFor(venues[i].id)),
                        ),
                      ),
              ),
      ),
    );
  }
}
