import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

/// Soft ivory box with an icon and a short explanation.
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
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: AppColors.ivory, borderRadius: BorderRadius.circular(16)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: iconColor),
          const SizedBox(width: 12),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
}
