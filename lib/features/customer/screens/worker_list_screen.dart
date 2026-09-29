import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/dzongkhags.dart';
import '../../../core/router/route_names.dart';
import '../../../core/strings/app_strings.dart';
import '../../../shared/widgets/async_view.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/worker_card.dart';
import '../providers/search_providers.dart';
import '../widgets/dzongkhag_selector.dart';
import '../widgets/sort_selector.dart';

/// C2 Worker list
/// Purpose: Show approved workers for a service and location.
/// Backend: worker_services for the category, then worker_directory by dzongkhag.
/// Done when: Only approved workers appear (admins also see ones awaiting approval).
class WorkerListScreen extends ConsumerWidget {
  const WorkerListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final category = ref.watch(selectedCategoryProvider);
    final results = ref.watch(workerSearchProvider);
    final everywhere = ref.watch(selectedDzongkhagProvider).valueOrNull == kAllDzongkhags;
    final service = category?.name ?? '';

    return Scaffold(
      appBar: AppBar(title: Text(category?.name ?? '')),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [DzongkhagSelector(), SortSelector()],
              ),
            ),
            Expanded(
              child: AsyncView(
                value: results,
                onRetry: () => ref.invalidate(workerSearchProvider),
                data: (results) => RefreshIndicator(
                  onRefresh: () => ref.refresh(workerSearchProvider.future),
                  child: results.isEmpty
                      // Scrollable, so pull-to-refresh still works.
                      ? LayoutBuilder(
                          builder: (context, constraints) => SingleChildScrollView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            child: SizedBox(
                              height: constraints.maxHeight,
                              child: EmptyState(
                                icon: Icons.person_search_outlined,
                                message: everywhere
                                    ? AppStrings.noWorkersAnywhere(service)
                                    : AppStrings.noWorkersYet(service),
                              ),
                            ),
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                          itemCount: results.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 12),
                          itemBuilder: (context, i) => WorkerCard(
                            worker: results[i].worker,
                            priceNote: results[i].priceNote,
                            onTap: () => context.push(Routes.workerDetailsFor(results[i].worker.id)),
                          ),
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
