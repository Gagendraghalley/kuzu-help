import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/dzongkhags.dart';
import '../../../core/strings/app_strings.dart';
import '../../../shared/widgets/choice_sheet.dart';
import '../providers/search_providers.dart';

/// Button showing the chosen dzongkhag; opens 'All dzongkhags' and a list of
/// all 20, narrowed by typing (a name, another spelling or a town).
/// Remembers the last choice on the phone (C1, C2).
class DzongkhagSelector extends ConsumerWidget {
  const DzongkhagSelector({super.key});

  static String _label(String dzongkhag) =>
      dzongkhag == kAllDzongkhags ? AppStrings.allDzongkhags : dzongkhag;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(selectedDzongkhagProvider).valueOrNull;

    return Tooltip(
      message: AppStrings.chooseArea,
      child: PillButton(
        icon: Icons.location_on_outlined,
        label: selected == null ? '…' : _label(selected),
        onPressed: selected == null
            ? null
            : () async {
                final choice = await showChoiceSheet<String>(
                  context,
                  title: AppStrings.chooseArea,
                  options: const [kAllDzongkhags, ...kDzongkhags],
                  selected: selected,
                  labelOf: _label,
                  searchHint: AppStrings.searchDzongkhags,
                  searchTermsOf: (d) => d == kAllDzongkhags ? const [] : dzongkhagSearchTerms(d),
                );
                if (choice != null) ref.read(selectedDzongkhagProvider.notifier).select(choice);
              },
      ),
    );
  }
}
