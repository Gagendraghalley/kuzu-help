import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/strings/app_strings.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/error_messages.dart';
import '../../../core/utils/text_utils.dart';
import '../../../shared/widgets/form_error.dart';
import '../../../shared/widgets/primary_button.dart';
import '../../../shared/widgets/section_header.dart';
import '../data/report_repository.dart';

/// C5 Report a worker
/// Purpose: Let customers flag problems.
/// Backend: Saves a row in reports with status open.
/// Done when: The report appears in the dashboard.
class ReportWorkerScreen extends ConsumerStatefulWidget {
  final String workerId;

  const ReportWorkerScreen({super.key, required this.workerId});

  @override
  ConsumerState<ReportWorkerScreen> createState() => _ReportWorkerScreenState();
}

class _ReportWorkerScreenState extends ConsumerState<ReportWorkerScreen> {
  static const _other = 'other';

  final _details = TextEditingController();
  String? _reason;
  bool _sending = false;
  String? _error;

  @override
  void dispose() {
    _details.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (_sending) return;
    final details = _details.text.orNull;
    final problem = _reason == null
        ? AppStrings.chooseReason
        : _reason == _other && details == null
            ? AppStrings.reportDetailsNeeded
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
      await ref
          .read(reportRepositoryProvider)
          .submitReport(workerId: widget.workerId, reason: _reason!, details: details);
      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      context.pop();
      messenger.showSnackBar(const SnackBar(content: Text(AppStrings.reportSent)));
    } catch (e) {
      if (mounted) setState(() => _error = ErrorMessages.from(e));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: const Text(AppStrings.reportWorker)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Text(AppStrings.reportIntro, style: text.bodyLarge?.copyWith(color: AppColors.inkSoft)),
            const SizedBox(height: 24),
            const SectionHeader(AppStrings.whatHappened),
            const SizedBox(height: 10),
            RadioGroup<String>(
              groupValue: _reason,
              onChanged: (reason) => setState(() {
                _reason = reason;
                _error = null;
              }),
              child: Card(
                child: Column(
                  children: [
                    for (final (i, reason) in ReportReasons.all.indexed) ...[
                      if (i > 0) const Divider(indent: 16, endIndent: 16),
                      RadioListTile<String>(
                        value: reason,
                        title: Text(AppStrings.reportReason(reason)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _details,
              minLines: 3,
              maxLines: 6,
              maxLength: 1000,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                labelText: _reason == _other ? AppStrings.reportDetails : AppStrings.reportDetailsOptional,
                hintText: AppStrings.reportDetailsHint,
                alignLabelWithHint: true,
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              FormError(_error!),
            ],
            const SizedBox(height: 24),
            PrimaryButton(label: AppStrings.sendReport, isLoading: _sending, onPressed: _send),
          ],
        ),
      ),
    );
  }
}
