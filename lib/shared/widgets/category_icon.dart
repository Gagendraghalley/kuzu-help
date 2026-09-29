import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

/// Rounded tile with the icon for a service category, chosen by its `icon`
/// name in service_categories. Material icons until the PNGs in
/// assets/icons/categories/ exist; unknown names get a toolbox.
class CategoryIcon extends StatelessWidget {
  final String? name;
  final double size;

  const CategoryIcon({super.key, required this.name, this.size = 56});

  static const _icons = {
    'plumber': Icons.plumbing_rounded,
    'electrician': Icons.electrical_services_rounded,
    'carpenter': Icons.carpenter_rounded,
    'appliance_repair': Icons.kitchen_rounded,
    'painter': Icons.format_paint_rounded,
    'mason': Icons.foundation_rounded,
  };

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFFF4EA), Color(0xFFFDE1C7)],
        ),
        borderRadius: BorderRadius.circular(size * 0.3),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.12)),
      ),
      child: Icon(_icons[name] ?? Icons.handyman_rounded, size: size * 0.52, color: AppColors.primaryDeep),
    );
  }
}
