import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/route_names.dart';
import '../../../core/strings/app_strings.dart';
import '../../../shared/widgets/async_view.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/worker_card.dart';
import '../providers/admin_providers.dart';

/// Admin: every worker waiting for approval, longest waiting first. Tapping
/// one opens their page (C3) with the 'Admin check' card.
class PendingWorkersScreen extends ConsumerWidget {
  const PendingWorkersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final workers = ref.watch(pendingWorkersProvider);

    return Scaffold(
      appBar: AppBar(title: const Text(AppStrings.workersAwaitingApproval)),
      body: SafeArea(
        child: AsyncView(
          value: workers,
          onRetry: () => ref.invalidate(pendingWorkersProvider),
          data: (workers) => RefreshIndicator(
            onRefresh: () => ref.refresh(pendingWorkersProvider.future),
            child: workers.isEmpty
                ? ListView(
                    // Scrollable, so pull-to-refresh still works.
                    children: const [
                      SizedBox(height: 120),
                      EmptyState(icon: Icons.verified_outlined, message: AppStrings.noneAwaitingApproval),
                    ],
                  )
                : ListView.separated(
                    padding: const EdgeInsets.all(16),
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
