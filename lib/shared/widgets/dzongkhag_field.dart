import 'package:flutter/material.dart';

import '../../core/constants/dzongkhags.dart';
import '../../core/strings/app_strings.dart';

/// Dropdown of the 20 dzongkhags for forms (B1, D1).
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
    return DropdownButtonFormField<String>(
      initialValue: kDzongkhags.contains(initialValue) ? initialValue : null,
      items: [for (final d in kDzongkhags) DropdownMenuItem(value: d, child: Text(d))],
      onChanged: onChanged,
      menuMaxHeight: 400,
      icon: const Icon(Icons.keyboard_arrow_down_rounded),
      borderRadius: BorderRadius.circular(16),
      dropdownColor: Colors.white,
      decoration: const InputDecoration(labelText: AppStrings.dzongkhag),
      validator: required ? (v) => v == null ? AppStrings.chooseDzongkhag : null : null,
    );
  }
}
