import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

/// Round icon for a service category, chosen by its `icon` name in
/// service_categories. Material icons until the PNGs in
/// assets/icons/categories/ exist; unknown names get a toolbox.
class CategoryIcon extends StatelessWidget {
  final String? name;
  final double size;

  const CategoryIcon({super.key, required this.name, this.size = 56});

  static const _icons = {
    'plumber': Icons.plumbing,
    'electrician': Icons.electrical_services,
    'carpenter': Icons.carpenter,
    'appliance_repair': Icons.kitchen,
    'painter': Icons.format_paint,
    'mason': Icons.foundation,
  };

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(color: AppColors.ivory, shape: BoxShape.circle),
      child: Icon(_icons[name] ?? Icons.handyman, size: size * 0.55, color: AppColors.primaryDeep),
    );
  }
}
