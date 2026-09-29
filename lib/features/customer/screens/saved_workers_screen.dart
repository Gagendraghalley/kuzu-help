import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/route_names.dart';
import '../../../core/strings/app_strings.dart';
import '../../../shared/widgets/async_view.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/worker_card.dart';
import '../providers/worker_details_providers.dart';

/// Saved workers (from C1): the ones the customer tapped the heart on, to call
/// again. Workers who are no longer listed drop out.
class SavedWorkersScreen extends ConsumerWidget {
  const SavedWorkersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final saved = ref.watch(savedWorkersProvider);

    return Scaffold(
      appBar: AppBar(title: const Text(AppStrings.savedWorkers)),
      body: SafeArea(
        child: AsyncView(
          value: saved,
          onRetry: () => ref.invalidate(savedWorkersProvider),
          data: (workers) => workers.isEmpty
              ? const EmptyState(icon: Icons.favorite_border, message: AppStrings.noSavedWorkers)
              : RefreshIndicator(
                  onRefresh: () => ref.refresh(savedWorkersProvider.future),
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                    itemCount: workers.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, i) => WorkerCard(
                      worker: workers[i],
                      onTap: () => context.push(Routes.workerDetailsFor(workers[i].id)),
                    ),
                  ),
                ),
        ),
      ),
    );
  }
}
