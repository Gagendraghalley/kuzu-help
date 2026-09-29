import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import 'icon_tile.dart';

/// A short explanation in a box tinted by [iconColor]: warm for tips, green
/// for reassurance, red for warnings.
class InfoNote extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color iconColor;

  const InfoNote({
    super.key,
    required this.icon,
    required this.text,
    this.iconColor = AppColors.primaryDeep,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Color.alphaBlend(iconColor.withValues(alpha: 0.05), Colors.white),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: iconColor.withValues(alpha: 0.16)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          IconTile(icon: icon, color: iconColor, size: 36),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(text, style: const TextStyle(color: AppColors.inkSoft, height: 1.45)),
            ),
          ),
        ],
      ),
    );
  }
}
