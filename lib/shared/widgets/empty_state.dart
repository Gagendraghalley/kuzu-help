import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

/// Friendly message when a list is empty, with an optional button.
class EmptyState extends StatelessWidget {
  final IconData icon;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  const EmptyState({
    super.key,
    required this.icon,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final actionLabel = this.actionLabel;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconHalo(icon: icon),
              const SizedBox(height: 24),
              Text(
                message,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: AppColors.inkSoft,
                      fontWeight: FontWeight.w600,
                      height: 1.45,
                    ),
              ),
              if (actionLabel != null) ...[
                const SizedBox(height: 24),
                FilledButton.tonal(
                  onPressed: onAction,
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(0, 50),
                    padding: const EdgeInsets.symmetric(horizontal: 28),
                  ),
                  child: Text(actionLabel),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// A large icon inside two soft rings, at the top of empty and error states.
class IconHalo extends StatelessWidget {
  final IconData icon;
  final Color color;

  const IconHalo({super.key, required this.icon, this.color = AppColors.primaryDeep});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 120,
      height: 120,
      decoration: BoxDecoration(shape: BoxShape.circle, color: color.withValues(alpha: 0.05)),
      alignment: Alignment.center,
      child: Container(
        width: 88,
        height: 88,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white,
          border: Border.all(color: color.withValues(alpha: 0.12)),
          boxShadow: [
            BoxShadow(color: color.withValues(alpha: 0.10), blurRadius: 20, offset: const Offset(0, 8)),
          ],
        ),
        child: Icon(icon, size: 40, color: color),
      ),
    );
  }
}
