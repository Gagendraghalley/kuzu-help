import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/route_names.dart';
import '../../../core/strings/app_strings.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/error_messages.dart';
import '../../../shared/models/verification.dart';
import '../../../shared/widgets/async_view.dart';
import '../../../shared/widgets/form_error.dart';
import '../../../shared/widgets/info_note.dart';
import '../../../shared/widgets/photo_picker.dart';
import '../../../shared/widgets/primary_button.dart';
import '../data/worker_repository.dart';
import '../providers/worker_providers.dart';
import '../widgets/setup_progress.dart';

/// B3 Verification
/// Purpose: Collect CID (and optional certificate) with consent.
/// Backend: Uploads to private verification-docs; saves paths in worker_verifications.
/// Done when: Files are in Storage; another user cannot open them.
/// Also opened from B4 to send new documents; then it goes back when saved.
class VerificationUploadScreen extends ConsumerWidget {
  const VerificationUploadScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final existing = ref.watch(myVerificationProvider);
    final editing = context.canPop();

    return Scaffold(
      appBar: AppBar(
        title: const Text(AppStrings.verificationTitle),
        leading: editing ? null : BackButton(onPressed: () => context.go(Routes.workerServices)),
      ),
      body: SafeArea(
        child: AsyncView(
          value: existing,
          onRetry: () => ref.invalidate(myVerificationProvider),
          data: (existing) => _VerificationForm(existing: existing, editing: editing),
        ),
      ),
    );
  }
}

class _VerificationForm extends ConsumerStatefulWidget {
  final Verification? existing;
  final bool editing;

  const _VerificationForm({required this.existing, required this.editing});

  @override
  ConsumerState<_VerificationForm> createState() => _VerificationFormState();
}

class _VerificationFormState extends ConsumerState<_VerificationForm> {
  Uint8List? _cid;
  Uint8List? _certificate;
  bool _consent = false;
  bool _sending = false;
  String? _error;

  Future<void> _send() async {
    if (_sending) return;
    final problem = _cid == null && widget.existing == null
        ? AppStrings.addCidPhoto
        : !_consent
            ? AppStrings.consentNeeded
            : null;
    if (problem != null) {
      setState(() => _error = problem);
      return;
    }
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      await ref.read(workerRepositoryProvider).submitVerification(cid: _cid, certificate: _certificate);
      ref.invalidate(myVerificationProvider);
      if (!mounted) return;
      if (widget.editing) {
        final messenger = ScaffoldMessenger.of(context);
        context.pop();
        messenger.showSnackBar(const SnackBar(content: Text(AppStrings.saved)));
      } else {
        context.go(Routes.workerPending);
      }
    } catch (e) {
      if (mounted) setState(() => _error = ErrorMessages.from(e));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        if (!widget.editing) ...[
          const SetupProgress(step: 3),
          const SizedBox(height: 20),
        ],
        const InfoNote(icon: Icons.lock_outline, text: AppStrings.cidExplanation),
        const SizedBox(height: 24),
        _DocumentTile(
          title: AppStrings.cidPhoto,
          icon: Icons.badge_outlined,
          picked: _cid,
          alreadySent: widget.existing != null,
          onPicked: (photo) => setState(() {
            _cid = photo;
            _error = null;
          }),
        ),
        const SizedBox(height: 12),
        _DocumentTile(
          title: AppStrings.certificatePhoto,
          hint: AppStrings.certificateHint,
          icon: Icons.workspace_premium_outlined,
          picked: _certificate,
          alreadySent: widget.existing?.certificatePath != null,
          onPicked: (photo) => setState(() => _certificate = photo),
        ),
        const SizedBox(height: 16),
        CheckboxListTile(
          value: _consent,
          onChanged: (v) => setState(() {
            _consent = v ?? false;
            _error = null;
          }),
          title: const Text(AppStrings.consent),
          controlAffinity: ListTileControlAffinity.leading,
          contentPadding: EdgeInsets.zero,
        ),
        if (_error != null) ...[
          const SizedBox(height: 8),
          FormError(_error!),
        ],
        const SizedBox(height: 24),
        PrimaryButton(
          label: widget.editing ? AppStrings.save : AppStrings.sendForChecking,
          isLoading: _sending,
          onPressed: _send,
        ),
      ],
    );
  }
}

/// One document: a preview once picked, and whether one was already sent.
class _DocumentTile extends StatelessWidget {
  final String title;
  final String? hint;
  final IconData icon;
  final Uint8List? picked;
  final bool alreadySent;
  final ValueChanged<Uint8List> onPicked;

  const _DocumentTile({
    required this.title,
    required this.icon,
    required this.picked,
    required this.alreadySent,
    required this.onPicked,
    this.hint,
  });

  @override
  Widget build(BuildContext context) {
    final picked = this.picked;
    final hint = this.hint;
    final done = picked != null || alreadySent;
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    final status = picked != null
        ? AppStrings.photoReady
        : alreadySent
            ? AppStrings.alreadySent
            : AppStrings.tapToAddPhoto;

    return Card(
      shape: done
          ? RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: BorderSide(color: AppColors.verified.withValues(alpha: 0.35)),
            )
          : null,
      child: InkWell(
        onTap: () async {
          final photo = await pickPhoto(context);
          if (photo != null) onPicked(photo);
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: SizedBox.square(
                  dimension: 72,
                  child: picked != null
                      ? Image.memory(picked, fit: BoxFit.cover)
                      : ColoredBox(
                          color: AppColors.peach,
                          child: Icon(icon, size: 34, color: AppColors.primaryDeep),
                        ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    if (hint != null) ...[
                      const SizedBox(height: 2),
                      Text(hint, style: TextStyle(color: muted, fontSize: 14.5)),
                    ],
                    const SizedBox(height: 4),
                    Text(
                      status,
                      style: TextStyle(
                        color: done ? AppColors.verified : AppColors.primaryDeep,
                        fontWeight: FontWeight.w600,
                        fontSize: 14.5,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                done ? Icons.check_circle_rounded : Icons.add_a_photo_outlined,
                color: done ? AppColors.verified : AppColors.primaryDeep,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
