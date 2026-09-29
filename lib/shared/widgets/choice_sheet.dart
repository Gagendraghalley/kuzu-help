import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

/// Bottom sheet listing [options], with a tick by [selected]. Returns the
/// option tapped, or null if dismissed (dzongkhag and sort pickers).
Future<T?> showChoiceSheet<T>(
  BuildContext context, {
  required String title,
  required List<T> options,
  required T? selected,
  required String Function(T option) labelOf,
}) {
  return showModalBottomSheet<T>(
    context: context,
    showDragHandle: true,
    // Tall enough to show most of the 20 dzongkhags at once.
    isScrollControlled: true,
    builder: (context) => SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.8),
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: Text(
                title,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
              ),
            ),
            for (final option in options)
              ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                selectedTileColor: AppColors.peach,
                title: Text(labelOf(option)),
                selected: option == selected,
                trailing: option == selected ? const Icon(Icons.check_rounded) : null,
                onTap: () => Navigator.pop(context, option),
              ),
          ],
        ),
      ),
    ),
  );
}

/// Rounded button showing the current choice, e.g. the dzongkhag (C1, C2).
class PillButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onPressed;

  const PillButton({super.key, required this.icon, required this.label, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        shape: const StadiumBorder(),
        minimumSize: const Size(0, 46),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        backgroundColor: Colors.white,
        side: const BorderSide(color: AppColors.outline, width: 1.2),
        foregroundColor: AppColors.ink,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 19, color: AppColors.primaryDeep),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(width: 4),
          const Icon(Icons.keyboard_arrow_down_rounded, size: 20, color: AppColors.muted),
        ],
      ),
    );
  }
}
