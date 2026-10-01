import 'package:flutter/material.dart';

import '../../core/constants/dzongkhags.dart';
import '../../core/strings/app_strings.dart';
import 'choice_sheet.dart';

/// The 20 dzongkhags for forms (B1, D1): looks like a dropdown, and opens a
/// list to pick from, narrowed by typing a name, another spelling or a town.
class DzongkhagField extends StatelessWidget {
  final String? initialValue;
  final ValueChanged<String?> onChanged;
  final bool required;

  const DzongkhagField({
    super.key,
    required this.initialValue,
    required this.onChanged,
    this.required = false,
  });

  @override
  Widget build(BuildContext context) {
    return FormField<String>(
      initialValue: kDzongkhags.contains(initialValue) ? initialValue : null,
      validator: required ? (v) => v == null ? AppStrings.chooseDzongkhag : null : null,
      builder: (field) {
        final value = field.value;
        return InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () async {
            final choice = await showChoiceSheet<String>(
              context,
              title: AppStrings.dzongkhag,
              options: kDzongkhags,
              selected: value,
              labelOf: (d) => d,
              searchHint: AppStrings.searchDzongkhags,
              searchTermsOf: dzongkhagSearchTerms,
            );
            if (choice == null) return;
            field.didChange(choice);
            onChanged(choice);
          },
          child: InputDecorator(
            isEmpty: value == null,
            decoration: InputDecoration(
              labelText: AppStrings.dzongkhag,
              errorText: field.errorText,
              suffixIcon: const Icon(Icons.keyboard_arrow_down_rounded),
            ),
            child: value == null ? null : Text(value),
          ),
        );
      },
    );
  }
}
