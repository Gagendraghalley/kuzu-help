import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

/// An icon on a softly tinted rounded square, as icons sit in menus, notes
/// and lists across the app. [color] tints both.
class IconTile extends StatelessWidget {
  final IconData icon;
  final Color color;
  final double size;

  const IconTile({super.key, required this.icon, this.color = AppColors.primaryDeep, this.size = 40});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(size * 0.3),
      ),
      child: Icon(icon, color: color, size: size * 0.52),
    );
  }
}
