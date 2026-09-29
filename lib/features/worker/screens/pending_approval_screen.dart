import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/router/route_names.dart';
import '../../../core/strings/app_strings.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/error_messages.dart';
import '../../../shared/widgets/app_bar_logo.dart';
import '../../../shared/widgets/async_view.dart';
import '../../../shared/widgets/primary_button.dart';
import '../../../shared/widgets/section_header.dart';
import '../../profile/widgets/settings_button.dart';
import '../data/worker_repository.dart';
import '../providers/worker_providers.dart';
import '../widgets/status_banner.dart';

/// B4 Pending approval
/// Purpose: Explain what happens next.
/// Backend: Reads verification_status and admin_notes from the worker's own row.
/// Done when: Status changes in the dashboard show after refresh.
class PendingApprovalScreen extends ConsumerStatefulWidget {
  const PendingApprovalScreen({super.key});

  @override
  ConsumerState<PendingApprovalScreen> createState() => _PendingApprovalScreenState();
}

class _PendingApprovalScreenState extends ConsumerState<PendingApprovalScreen> {
  bool _sending = false;

  Future<void> _refresh() => ref.refresh(myWorkerProfileProvider.future);

  /// Rejected workers, once they've fixed things.
  Future<void> _sendAgain() async {
    setState(() => _sending = true);
    try {
      await ref.read(workerRepositoryProvider).requestReview();
      await _refresh();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(ErrorMessages.from(e))));
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final worker = ref.watch(myWorkerProfileProvider);

    return Scaffold(
      appBar: AppBar(title: const AppBarLogo(), actions: const [SettingsButton()]),
      body: SafeArea(
        child: AsyncView(
          value: worker,
          onRetry: () => ref.invalidate(myWorkerProfileProvider),
          data: (worker) {
            final status = worker?.verificationStatus ?? VerificationStatus.pending;
            return RefreshIndicator(
              onRefresh: _refresh,
              child: ListView(
                padding: const EdgeInsets.all(24),
                children: [
                  StatusBanner(status: status, adminNote: worker?.adminNotes),
                  const SizedBox(height: 24),
                  ...switch (status) {
                    VerificationStatus.approved => [
                        PrimaryButton(
                          label: AppStrings.goToDashboard,
                          onPressed: () => context.go(Routes.workerDashboard),
                        ),
                      ],
                    VerificationStatus.rejected => [
                        const _EditLinks(),
                        const SizedBox(height: 24),
                        PrimaryButton(label: AppStrings.sendAgain, isLoading: _sending, onPressed: _sendAgain),
                      ],
                    _ => [
                        const _Checklist(),
                        const SizedBox(height: 16),
                        OutlinedButton.icon(
                          icon: const Icon(Icons.refresh),
                          label: const Text(AppStrings.checkAgain),
                          style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(52)),
                          onPressed: _refresh,
                        ),
                        const SizedBox(height: 32),
                        const SectionHeader(AppStrings.needChanges),
                        const SizedBox(height: 8),
                        const _EditLinks(),
                      ],
                  },
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

/// Profile, services and documents are in; the team check is next.
class _Checklist extends StatelessWidget {
  const _Checklist();

  @override
  Widget build(BuildContext context) {
    Widget step(String label, {required bool done}) => ListTile(
          leading: Icon(
            done ? Icons.check_circle : Icons.hourglass_top,
            color: done ? AppColors.verified : AppColors.primaryDeep,
          ),
          title: Text(label),
          trailing: Text(
            done ? AppStrings.stepDone : AppStrings.stepWaiting,
            style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
          ),
        );

    return Card(
      child: Column(
        children: [
          step(AppStrings.stepProfile, done: true),
          step(AppStrings.stepServices, done: true),
          step(AppStrings.stepDocuments, done: true),
          step(AppStrings.stepTeamCheck, done: false),
        ],
      ),
    );
  }
}

/// Opens B1–B3 to change the details sent.
class _EditLinks extends StatelessWidget {
  const _EditLinks();

  @override
  Widget build(BuildContext context) {
    Widget link(IconData icon, String label, String route) => ListTile(
          leading: Icon(icon, color: Theme.of(context).colorScheme.primary),
          title: Text(label),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => context.push(route),
        );

    return Card(
      child: Column(
        children: [
          link(Icons.person_outline, AppStrings.editProfile, Routes.workerSetup),
          const Divider(indent: 16, endIndent: 16),
          link(Icons.handyman_outlined, AppStrings.editServices, Routes.workerServices),
          const Divider(indent: 16, endIndent: 16),
          link(Icons.badge_outlined, AppStrings.updateDocuments, Routes.workerVerification),
        ],
      ),
    );
  }
}
