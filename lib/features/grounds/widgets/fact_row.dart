import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/icon_tile.dart';

/// 'Label: value' beside an icon, in a booking's details.
class FactRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const FactRow({super.key, required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          IconTile(icon: icon, size: 34),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 5),
              child: Text.rich(TextSpan(children: [
                TextSpan(text: '$label: ', style: const TextStyle(fontWeight: FontWeight.w700)),
                TextSpan(text: value, style: const TextStyle(color: AppColors.inkSoft)),
              ])),
            ),
          ),
        ],
      ),
    );
  }
}

/// The other person's message, in a warm box under the details.
class MessageBox extends StatelessWidget {
  final String title;
  final String message;

  const MessageBox({super.key, required this.title, required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF8F1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: Theme.of(context)
                  .textTheme
                  .labelLarge
                  ?.copyWith(color: AppColors.primaryDeep, fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text(message, style: const TextStyle(color: AppColors.inkSoft)),
        ],
      ),
    );
  }
}
