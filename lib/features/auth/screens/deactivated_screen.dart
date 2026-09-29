import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/strings/app_strings.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/primary_button.dart';
import '../../profile/providers/profile_providers.dart';
import '../providers/auth_providers.dart';

/// Shown instead of everything else when an admin has deactivated
/// (blacklisted) the account. The database also refuses their changes
/// (supabase/updates.sql). The only way out is to log out.
class DeactivatedScreen extends ConsumerWidget {
  const DeactivatedScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reason = ref.watch(myProfileProvider).valueOrNull?.deactivatedReason?.trim() ?? '';
    final text = Theme.of(context).textTheme;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 96,
                    height: 96,
                    decoration: BoxDecoration(
                      color: AppColors.error.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.block, size: 48, color: AppColors.error),
                  ),
                ),
                const SizedBox(height: 20),
                Semantics(
                  header: true,
                  child: Text(
                    AppStrings.deactivatedTitle,
                    textAlign: TextAlign.center,
                    style: text.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(height: 8),
                Text(AppStrings.deactivatedMessage, textAlign: TextAlign.center, style: text.bodyLarge),
                if (reason.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(color: AppColors.ivory, borderRadius: BorderRadius.circular(12)),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(AppStrings.adminNoteLabel, style: text.labelLarge?.copyWith(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 4),
                        Text(reason, style: text.bodyLarge),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 32),
                PrimaryButton(
                  label: AppStrings.logout,
                  onPressed: () => ref.read(authActionsProvider).signOut(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
