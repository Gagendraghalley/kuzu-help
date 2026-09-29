import 'package:flutter/material.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/strings/app_strings.dart';
import '../../../core/theme/app_colors.dart';

/// Pending / approved / rejected banner with the admin note (B4).
class StatusBanner extends StatelessWidget {
  final String status;
  final String? adminNote;

  const StatusBanner({super.key, required this.status, this.adminNote});

  @override
  Widget build(BuildContext context) {
    final (icon, color, title, message) = switch (status) {
      VerificationStatus.approved =>
        (Icons.verified, AppColors.verified, AppStrings.approvedTitle, AppStrings.approvedMessage),
      VerificationStatus.rejected =>
        (Icons.error_outline, AppColors.error, AppStrings.rejectedTitle, AppStrings.rejectedMessage),
      _ => (Icons.hourglass_top, AppColors.primaryDeep, AppStrings.pendingTitle, AppStrings.pendingMessage),
    };
    final note = adminNote?.trim() ?? '';
    final text = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, size: 56, color: color),
          const SizedBox(height: 12),
          Semantics(
            header: true,
            child: Text(
              title,
              textAlign: TextAlign.center,
              style: text.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(height: 8),
          Text(message, textAlign: TextAlign.center, style: text.bodyLarge),
          if (status == VerificationStatus.rejected && note.isNotEmpty) ...[
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(AppStrings.adminNoteLabel, style: text.labelLarge?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text(note, style: text.bodyLarge),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
