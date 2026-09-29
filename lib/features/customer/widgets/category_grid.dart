import 'package:flutter/material.dart';

import '../../../shared/models/service_category.dart';
import '../../../shared/widgets/category_icon.dart';

/// Grid of service categories with icons (C1). Two big tiles per row; each
/// row grows to fit large text.
class CategoryGrid extends StatelessWidget {
  final List<ServiceCategory> categories;
  final ValueChanged<ServiceCategory> onTap;

  const CategoryGrid({super.key, required this.categories, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var i = 0; i < categories.length; i += 2)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(child: _CategoryTile(category: categories[i], onTap: onTap)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: i + 1 < categories.length
                        ? _CategoryTile(category: categories[i + 1], onTap: onTap)
                        : const SizedBox.shrink(),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _CategoryTile extends StatelessWidget {
  final ServiceCategory category;
  final ValueChanged<ServiceCategory> onTap;

  const _CategoryTile({required this.category, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => onTap(category),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 12),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CategoryIcon(name: category.icon, size: 64),
              const SizedBox(height: 12),
              Text(
                category.name,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
