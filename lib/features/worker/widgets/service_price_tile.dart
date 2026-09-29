import 'package:flutter/material.dart';

import '../../../core/strings/app_strings.dart';
import '../../../shared/models/service_category.dart';
import '../../../shared/widgets/category_icon.dart';

/// Checkbox + optional price note for one service (B2).
class ServicePriceTile extends StatelessWidget {
  final ServiceCategory category;
  final bool selected;
  final TextEditingController priceNote;
  final ValueChanged<bool> onSelected;

  const ServicePriceTile({
    super.key,
    required this.category,
    required this.selected,
    required this.priceNote,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(20),
      side: BorderSide(color: selected ? colors.primary : colors.outlineVariant, width: selected ? 1.8 : 1),
    );

    return Card(
      shape: shape,
      color: selected ? const Color(0xFFFFFBF7) : Colors.white,
      child: Column(
        children: [
          CheckboxListTile(
            value: selected,
            onChanged: (value) => onSelected(value ?? false),
            secondary: CategoryIcon(name: category.icon, size: 48),
            title: Text(
              category.name,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          ),
          if (selected)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: TextFormField(
                controller: priceNote,
                maxLength: 100,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: AppStrings.priceNote,
                  hintText: AppStrings.priceNoteHint,
                  counterText: '',
                ),
              ),
            ),
        ],
      ),
    );
  }
}
