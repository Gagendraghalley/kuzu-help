import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/router/route_names.dart';
import '../../../core/strings/app_strings.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/error_messages.dart';
import '../../../shared/models/report.dart';
import '../../../shared/widgets/async_view.dart';
import '../../../shared/widgets/avatar_image.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/info_note.dart';
import '../../customer/providers/worker_details_providers.dart';
import '../data/admin_repository.dart';
import '../providers/admin_providers.dart';

/// Admin: reports customers sent about workers (C5), open ones first. Tap one
/// to read it, open the worker's page, or mark it reviewed or closed.
class ReportsScreen extends ConsumerWidget {
  const ReportsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(reportStatusFilterProvider);
    final reports = ref.watch(reportsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text(AppStrings.reports)),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: SizedBox(
                width: double.infinity,
                child: SegmentedButton<String>(
                  showSelectedIcon: false,
                  segments: [
                    for (final s in ReportStatus.all)
                      ButtonSegment(value: s, label: Text(AppStrings.reportStatusLabel(s))),
                  ],
                  selected: {status},
                  onSelectionChanged: (s) => ref.read(reportStatusFilterProvider.notifier).state = s.single,
                ),
              ),
            ),
            Expanded(
              child: AsyncView(
                value: reports,
                onRetry: () => ref.invalidate(reportsProvider),
                data: (reports) => RefreshIndicator(
                  onRefresh: () => ref.refresh(reportsProvider.future),
                  child: reports.isEmpty
                      ? ListView(
                          // Scrollable, so pull-to-refresh still works.
                          children: [
                            const SizedBox(height: 80),
                            EmptyState(icon: Icons.flag_outlined, message: AppStrings.noReports(status)),
                          ],
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                          itemCount: reports.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 8),
                          itemBuilder: (context, i) => _ReportTile(report: reports[i]),
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReportTile extends StatelessWidget {
  final Report report;

  const _ReportTile({required this.report});

  @override
  Widget build(BuildContext context) {
    final details = report.details?.trim() ?? '';
    final muted = TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 14);

    return Card(
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: AvatarImage(url: report.workerAvatarUrl, name: report.workerName, size: 48),
        title: Text(report.workerName, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(AppStrings.reportReason(report.reason), style: const TextStyle(fontWeight: FontWeight.w500)),
            if (details.isNotEmpty) Text(details, maxLines: 2, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 4),
            Text('${AppStrings.reportedBy(report.reporterName)} · ${AppStrings.timeAgo(report.createdAt)}',
                style: muted),
          ],
        ),
        trailing: const Icon(Icons.more_vert),
        onTap: () => showModalBottomSheet<void>(
          context: context,
          showDragHandle: true,
          isScrollControlled: true,
          builder: (_) => _ReportActions(report: report),
        ),
      ),
    );
  }
}

/// The whole report, and what an admin can do with it.
class _ReportActions extends ConsumerStatefulWidget {
  final Report report;

  const _ReportActions({required this.report});

  @override
  ConsumerState<_ReportActions> createState() => _ReportActionsState();
}

class _ReportActionsState extends ConsumerState<_ReportActions> {
  bool _saving = false;

  Future<void> _setStatus(String status) async {
    setState(() => _saving = true);
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    try {
      await ref.read(adminRepositoryProvider).setReportStatus(widget.report.id, status);
      ref.invalidate(reportsProvider);
      navigator.pop();
      messenger.showSnackBar(SnackBar(content: Text(AppStrings.reportStatusChanged(status))));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(ErrorMessages.from(e))));
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final report = widget.report;
    final details = report.details?.trim() ?? '';
    final text = Theme.of(context).textTheme;
    final muted = TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant);

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(AppStrings.reportReason(report.reason),
                style: text.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text('${AppStrings.reportedBy(report.reporterName)} · ${AppStrings.shortDate(report.createdAt)}',
                style: muted),
            if (report.reporterEmail case final email?) Text(email, style: muted),
            if (details.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(details, style: text.bodyLarge),
            ],
            const SizedBox(height: 16),
            const InfoNote(icon: Icons.info_outline, text: AppStrings.reportHandlingHint),
            const SizedBox(height: 8),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: AvatarImage(url: report.workerAvatarUrl, name: report.workerName, size: 40),
              title: Text(report.workerName, style: const TextStyle(fontWeight: FontWeight.w600)),
              subtitle: const Text(AppStrings.openWorkerPage),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Navigator.pop(context);
                ref.invalidate(workerDetailsProvider(report.workerId));
                context.push(Routes.workerDetailsFor(report.workerId));
              },
            ),
            const SizedBox(height: 8),
            if (_saving)
              const Center(child: CircularProgressIndicator())
            else if (report.status == ReportStatus.open) ...[
              FilledButton.icon(
                style: FilledButton.styleFrom(backgroundColor: AppColors.verified),
                icon: const Icon(Icons.check),
                label: const Text(AppStrings.markReviewed),
                onPressed: () => _setStatus(ReportStatus.reviewed),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(52)),
                icon: const Icon(Icons.archive_outlined),
                label: const Text(AppStrings.closeReport),
                onPressed: () => _setStatus(ReportStatus.closed),
              ),
            ] else ...[
              if (report.status == ReportStatus.reviewed) ...[
                FilledButton.icon(
                  icon: const Icon(Icons.archive_outlined),
                  label: const Text(AppStrings.closeReport),
                  onPressed: () => _setStatus(ReportStatus.closed),
                ),
                const SizedBox(height: 8),
              ],
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(52)),
                icon: const Icon(Icons.undo),
                label: const Text(AppStrings.reopenReport),
                onPressed: () => _setStatus(ReportStatus.open),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
