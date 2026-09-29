import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/strings/app_strings.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/error_messages.dart';
import '../../../shared/models/worker_listing.dart';
import '../../../shared/widgets/section_header.dart';
import '../../customer/providers/search_providers.dart';
import '../../customer/providers/worker_details_providers.dart';
import '../data/admin_repository.dart';
import '../providers/admin_providers.dart';
import 'note_dialog.dart';

/// 'Admin check' on a worker's page (C3), for admins only: their documents,
/// Approve / Reject, and Deactivate. Customers only see approved, active workers.
class AdminReviewCard extends ConsumerStatefulWidget {
  final WorkerListing worker;

  const AdminReviewCard({super.key, required this.worker});

  @override
  ConsumerState<AdminReviewCard> createState() => _AdminReviewCardState();
}

class _AdminReviewCardState extends ConsumerState<AdminReviewCard> {
  bool _saving = false;

  /// Runs an admin [action], then refreshes everything showing this worker.
  Future<void> _run(Future<void> Function(AdminRepository admin) action, String done) async {
    setState(() => _saving = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await action(ref.read(adminRepositoryProvider));
      ref.invalidate(workerDetailsProvider(widget.worker.id));
      ref.invalidate(workerSearchProvider);
      ref.invalidate(pendingWorkersProvider);
      ref.invalidate(usersProvider);
      messenger.showSnackBar(SnackBar(content: Text(done)));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(ErrorMessages.from(e))));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _approve() => _run(
        (admin) => admin.setVerification(widget.worker.id, VerificationStatus.approved),
        AppStrings.workerApproved(widget.worker.fullName),
      );

  Future<void> _reject() async {
    final note = await showNoteDialog(
      context,
      title: AppStrings.rejectTitle,
      hint: AppStrings.rejectHint,
      confirmLabel: AppStrings.reject,
      requiredMessage: AppStrings.rejectNoteNeeded,
    );
    if (note == null) return;
    await _run(
      (admin) => admin.setVerification(widget.worker.id, VerificationStatus.rejected, note: note),
      AppStrings.workerRejected(widget.worker.fullName),
    );
  }

  Future<void> _deactivate() async {
    final reason = await showNoteDialog(
      context,
      title: AppStrings.deactivateTitle,
      hint: AppStrings.deactivateHint,
      confirmLabel: AppStrings.deactivate,
    );
    if (reason == null) return;
    await _run(
      (admin) => admin.setUserActive(widget.worker.id, active: false, reason: reason),
      AppStrings.userDeactivated(widget.worker.fullName),
    );
  }

  void _reactivate() => _run(
        (admin) => admin.setUserActive(widget.worker.id, active: true),
        AppStrings.userReactivated(widget.worker.fullName),
      );

  @override
  Widget build(BuildContext context) {
    final worker = widget.worker;
    final status = worker.verificationStatus;
    final documents = ref.watch(workerDocumentsProvider(worker.id));

    return Card(
      color: AppColors.ivory,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: AppColors.primary.withValues(alpha: 0.4)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SectionHeader(AppStrings.adminCheck),
            const SizedBox(height: 6),
            Text(switch (status) {
              _ when !worker.isActive => AppStrings.deactivatedWorkerHint,
              VerificationStatus.approved => AppStrings.adminApprovedHint,
              VerificationStatus.rejected => AppStrings.adminRejectedHint,
              _ => AppStrings.adminPendingHint,
            }),
            const SizedBox(height: 16),
            documents.when(
              loading: () => const SizedBox(height: 96, child: Center(child: CircularProgressIndicator())),
              error: (e, _) => Text(ErrorMessages.from(e)),
              data: (docs) => docs == null
                  ? Text(AppStrings.noDocumentsYet, style: TextStyle(color: Theme.of(context).colorScheme.error))
                  : Row(
                      children: [
                        _DocumentThumb(label: AppStrings.cid, url: docs.cidUrl),
                        if (docs.certificateUrl case final certificate?) ...[
                          const SizedBox(width: 12),
                          _DocumentThumb(label: AppStrings.certificate, url: certificate),
                        ],
                      ],
                    ),
            ),
            const SizedBox(height: 16),
            if (_saving)
              const Center(child: CircularProgressIndicator())
            else if (!worker.isActive)
              FilledButton.icon(
                style: FilledButton.styleFrom(backgroundColor: AppColors.verified),
                icon: const Icon(Icons.lock_open),
                label: const Text(AppStrings.reactivateAccount),
                onPressed: _reactivate,
              )
            else ...[
              Row(
                children: [
                  if (status != VerificationStatus.approved)
                    Expanded(
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(backgroundColor: AppColors.verified),
                        icon: const Icon(Icons.check),
                        label: const Text(AppStrings.approve),
                        onPressed: _approve,
                      ),
                    ),
                  if (status == VerificationStatus.pending) const SizedBox(width: 12),
                  if (status != VerificationStatus.rejected)
                    Expanded(
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size.fromHeight(52),
                          foregroundColor: AppColors.error,
                          side: const BorderSide(color: AppColors.error),
                        ),
                        icon: const Icon(Icons.close),
                        label: const Text(AppStrings.reject),
                        onPressed: _reject,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 4),
              TextButton.icon(
                style: TextButton.styleFrom(foregroundColor: AppColors.error),
                icon: const Icon(Icons.block),
                label: const Text(AppStrings.deactivateAccount),
                onPressed: _deactivate,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// A document photo; tap to see it full size.
class _DocumentThumb extends StatelessWidget {
  final String label;
  final String url;

  const _DocumentThumb({required this.label, required this.url});

  @override
  Widget build(BuildContext context) {
    Widget broken() => const ColoredBox(color: Colors.white, child: Icon(Icons.broken_image_outlined));

    return Column(
      children: [
        InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => showDialog<void>(
            context: context,
            builder: (context) => Dialog.fullscreen(
              backgroundColor: Colors.black,
              child: Stack(
                children: [
                  Positioned.fill(
                    child: InteractiveViewer(
                      child: Image.network(url, errorBuilder: (_, __, ___) => broken()),
                    ),
                  ),
                  SafeArea(
                    child: IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
                      tooltip: AppStrings.close,
                      onPressed: () => Navigator.pop(context),
                    ),
                  ),
                ],
              ),
            ),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: SizedBox(
              width: 120,
              height: 80,
              child: Image.network(url, fit: BoxFit.cover, errorBuilder: (_, __, ___) => broken()),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(label, style: Theme.of(context).textTheme.labelLarge),
      ],
    );
  }
}
