import 'package:flutter/material.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/strings/app_strings.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/empty_state.dart';

/// Pending / approved / rejected banner with the admin note (B4).
class StatusBanner extends StatelessWidget {
  final String status;
  final String? adminNote;

  const StatusBanner({super.key, required this.status, this.adminNote});

  @override
  Widget build(BuildContext context) {
    final (icon, color, title, message) = switch (status) {
      VerificationStatus.approved =>
        (Icons.verified_rounded, AppColors.verified, AppStrings.approvedTitle, AppStrings.approvedMessage),
      VerificationStatus.rejected =>
        (Icons.error_outline_rounded, AppColors.error, AppStrings.rejectedTitle, AppStrings.rejectedMessage),
      _ => (Icons.hourglass_top_rounded, AppColors.primaryDeep, AppStrings.pendingTitle, AppStrings.pendingMessage),
    };
    final note = adminNote?.trim() ?? '';
    final text = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: color.withValues(alpha: 0.25)),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color.alphaBlend(color.withValues(alpha: 0.08), Colors.white), Colors.white],
        ),
      ),
      child: Column(
        children: [
          IconHalo(icon: icon, color: color),
          const SizedBox(height: 16),
          Semantics(
            header: true,
            child: Text(title, textAlign: TextAlign.center, style: text.headlineSmall),
          ),
          const SizedBox(height: 8),
          Text(message, textAlign: TextAlign.center, style: text.bodyLarge?.copyWith(color: AppColors.inkSoft)),
          if (status == VerificationStatus.rejected && note.isNotEmpty) ...[
            const SizedBox(height: 20),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.canvas,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.line),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    AppStrings.adminNoteLabel,
                    style: text.labelLarge?.copyWith(fontWeight: FontWeight.w700, color: AppColors.muted),
                  ),
                  const SizedBox(height: 6),
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
