import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/strings/app_strings.dart';
import '../../../shared/widgets/choice_sheet.dart';
import '../providers/search_providers.dart';

/// Highest rated / most reviews / most experienced (C2).
class SortSelector extends ConsumerWidget {
  const SortSelector({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sort = ref.watch(workerSortProvider);

    return Tooltip(
      message: AppStrings.sortBy,
      child: PillButton(
        icon: Icons.sort,
        label: AppStrings.sortLabel(sort),
        onPressed: () async {
          final choice = await showChoiceSheet<WorkerSort>(
            context,
            title: AppStrings.sortBy,
            options: WorkerSort.values,
            selected: sort,
            labelOf: AppStrings.sortLabel,
          );
          if (choice != null) ref.read(workerSortProvider.notifier).state = choice;
        },
      ),
    );
  }
}
