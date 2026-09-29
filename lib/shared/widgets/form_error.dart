import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

/// What went wrong with a form, in a soft red box above its button. Screen
/// readers announce it as soon as it appears.
class FormError extends StatelessWidget {
  final String message;

  const FormError(this.message, {super.key});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.error.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.error.withValues(alpha: 0.25)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.error_outline_rounded, color: AppColors.error, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(color: AppColors.error, fontWeight: FontWeight.w600, height: 1.4),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
