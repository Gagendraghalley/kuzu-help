import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/route_names.dart';
import '../../../core/strings/app_strings.dart';
import '../../../shared/widgets/async_view.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/worker_card.dart';
import '../providers/search_providers.dart';

/// Search by name (from C1): listed workers anywhere in Bhutan whose name
/// contains what's typed, best rated first.
class SearchWorkersScreen extends ConsumerWidget {
  const SearchWorkersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final query = ref.watch(nameSearchProvider).trim();
    final results = ref.watch(nameSearchResultsProvider);

    return Scaffold(
      appBar: AppBar(
        centerTitle: false,
        title: TextField(
          autofocus: true,
          textInputAction: TextInputAction.search,
          decoration: const InputDecoration(
            hintText: AppStrings.searchWorkers,
            border: InputBorder.none,
          ),
          onChanged: (text) => ref.read(nameSearchProvider.notifier).state = text,
        ),
      ),
      body: SafeArea(
        child: query.length < 2
            ? const EmptyState(icon: Icons.search, message: AppStrings.typeToSearch)
            : AsyncView(
                value: results,
                onRetry: () => ref.invalidate(nameSearchResultsProvider),
                data: (workers) => workers.isEmpty
                    ? EmptyState(icon: Icons.person_search_outlined, message: AppStrings.noWorkersNamed(query))
                    : ListView.separated(
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
    );
  }
}
