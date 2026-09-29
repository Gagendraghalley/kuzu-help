import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/router/route_names.dart';
import '../../../core/strings/app_strings.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/error_messages.dart';
import '../../../core/utils/launcher_utils.dart';
import '../../../shared/models/job_request.dart';
import '../../../shared/widgets/async_view.dart';
import '../../../shared/widgets/category_icon.dart';
import '../../../shared/widgets/confirm_dialog.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/photo_viewer.dart';
import '../../../shared/widgets/text_dialog.dart';
import '../../customer/providers/worker_details_providers.dart';
import '../../profile/providers/profile_providers.dart';
import '../data/job_repository.dart';
import '../providers/job_providers.dart';

/// Job requests
/// Purpose: Customers follow the requests they sent; workers answer the ones
/// sent to them.
/// Backend: Reads job_requests; changes status with set_job_status.
/// Done when: Each answer reaches the other person as a notification.
class JobsScreen extends ConsumerStatefulWidget {
  const JobsScreen({super.key});

  @override
  ConsumerState<JobsScreen> createState() => _JobsScreenState();
}

class _JobsScreenState extends ConsumerState<JobsScreen> {
  bool _showActive = true;

  @override
  Widget build(BuildContext context) {
    final jobs = ref.watch(myJobsProvider);
    final asWorker = ref.watch(myProfileProvider).valueOrNull?.role == UserRole.worker;

    return Scaffold(
      appBar: AppBar(title: Text(asWorker ? AppStrings.jobRequests : AppStrings.myJobRequests)),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: SizedBox(
                width: double.infinity,
                child: SegmentedButton<bool>(
                  showSelectedIcon: false,
                  segments: const [
                    ButtonSegment(value: true, label: Text(AppStrings.activeJobs)),
                    ButtonSegment(value: false, label: Text(AppStrings.pastJobs)),
                  ],
                  selected: {_showActive},
                  onSelectionChanged: (s) => setState(() => _showActive = s.single),
                ),
              ),
            ),
            Expanded(
              child: AsyncView(
                value: jobs,
                onRetry: () => ref.invalidate(myJobsProvider),
                data: (jobs) {
                  final shown = jobs.where((j) => j.isOpen == _showActive).toList();
                  return RefreshIndicator(
                    onRefresh: () => ref.refresh(myJobsProvider.future),
                    child: shown.isEmpty
                        ? ListView(
                            // Scrollable, so pull-to-refresh still works.
                            children: [
                              const SizedBox(height: 80),
                              EmptyState(
                                icon: Icons.assignment_outlined,
                                message: AppStrings.noJobs(active: _showActive, asWorker: asWorker),
                              ),
                            ],
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                            itemCount: shown.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 8),
                            itemBuilder: (context, i) => _JobTile(job: shown[i], asWorker: asWorker),
                          ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _JobTile extends StatelessWidget {
  final JobRequest job;
  final bool asWorker;

  const _JobTile({required this.job, required this.asWorker});

  @override
  Widget build(BuildContext context) {
    final muted = TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 14);
    return Card(
      clipBehavior: Clip.antiAlias,
      color: asWorker && job.status == JobStatus.pending ? AppColors.ivory : null,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CategoryIcon(name: job.categoryIcon, size: 44),
        title: Text(
          asWorker ? AppStrings.jobFrom(job.customerName) : AppStrings.jobTo(job.workerName),
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(job.description, maxLines: 2, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                _StatusChip(status: job.status),
                Text(AppStrings.timeAgo(job.createdAt), style: muted),
              ],
            ),
          ],
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => showModalBottomSheet<void>(
          context: context,
          showDragHandle: true,
          isScrollControlled: true,
          builder: (_) => _JobDetails(job: job, asWorker: asWorker),
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String status;

  const _StatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      JobStatus.accepted => AppColors.verified,
      JobStatus.completed => AppColors.verified,
      JobStatus.declined || JobStatus.cancelled => AppColors.unavailable,
      _ => AppColors.primaryDeep,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(AppStrings.jobStatusLabel(status),
          style: TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 13)),
    );
  }
}

/// Everything about one request, and what this person can do with it now.
class _JobDetails extends ConsumerStatefulWidget {
  final JobRequest job;
  final bool asWorker;

  const _JobDetails({required this.job, required this.asWorker});

  @override
  ConsumerState<_JobDetails> createState() => _JobDetailsState();
}

class _JobDetailsState extends ConsumerState<_JobDetails> {
  bool _saving = false;

  /// Accepting and declining ask for an optional note; the rest ask to confirm.
  Future<void> _setStatus(String status) async {
    String? note;
    switch (status) {
      case JobStatus.accepted || JobStatus.declined:
        final accepting = status == JobStatus.accepted;
        note = await showTextDialog(
          context,
          title: accepting ? AppStrings.acceptJobTitle : AppStrings.declineJobTitle,
          hint: accepting ? AppStrings.acceptJobHint : AppStrings.declineJobHint,
          confirmLabel: accepting ? AppStrings.acceptJob : AppStrings.declineJob,
        );
        if (note == null) return;
      default:
        final cancelling = status == JobStatus.cancelled;
        final ok = await confirm(
          context,
          title: cancelling ? AppStrings.cancelRequestTitle : AppStrings.markDoneTitle,
          confirmLabel: cancelling ? AppStrings.cancelRequest : AppStrings.markDone,
          destructive: cancelling,
        );
        if (!ok) return;
    }
    if (!mounted) return;
    setState(() => _saving = true);
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    try {
      await ref.read(jobRepositoryProvider).setStatus(widget.job.id, status, note: note);
      ref.invalidate(myJobsProvider);
      navigator.pop();
      messenger.showSnackBar(SnackBar(content: Text(AppStrings.jobStatusChanged(status))));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(ErrorMessages.from(e))));
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final job = widget.job;
    final asWorker = widget.asWorker;
    final text = Theme.of(context).textTheme;
    final note = job.workerNote?.trim() ?? '';

    Widget fact(IconData icon, String label, String value) => Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 20, color: AppColors.primaryDeep),
              const SizedBox(width: 10),
              Expanded(
                child: Text.rich(TextSpan(children: [
                  TextSpan(text: '$label: ', style: const TextStyle(fontWeight: FontWeight.w600)),
                  TextSpan(text: value),
                ])),
              ),
            ],
          ),
        );

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              asWorker ? AppStrings.jobFrom(job.customerName) : AppStrings.jobTo(job.workerName),
              style: text.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            // Wraps, so large text never runs off the screen.
            Wrap(
              spacing: 8,
              runSpacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                _StatusChip(status: job.status),
                if (job.categoryName case final category?) Text(category),
              ],
            ),
            const SizedBox(height: 16),
            Text(job.description, style: text.bodyLarge),
            const SizedBox(height: 16),
            fact(Icons.location_on_outlined, AppStrings.jobWhereLabel, job.address),
            if (job.whenNeeded case final needed?) fact(Icons.schedule, AppStrings.jobWhenLabel, needed),
            fact(Icons.phone_outlined, AppStrings.jobPhoneLabel, job.contactPhone),
            if (job.photoPath case final path?) _JobPhoto(path: path),
            if (note.isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: AppColors.ivory, borderRadius: BorderRadius.circular(12)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(AppStrings.messageFromWorker,
                        style: text.labelLarge?.copyWith(color: AppColors.primaryDeep)),
                    const SizedBox(height: 4),
                    Text(note),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 16),
            if (_saving)
              const Center(child: CircularProgressIndicator())
            else
              ..._actions(job, asWorker),
          ],
        ),
      ),
    );
  }

  List<Widget> _actions(JobRequest job, bool asWorker) {
    const gap = SizedBox(height: 8);
    final outlined = OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(52));
    return [
      // The worker calls or messages the customer about an open job.
      if (asWorker && job.isOpen) ...[
        Row(
          children: [
            Expanded(
              child: FilledButton.icon(
                icon: const Icon(Icons.call),
                label: const Text(AppStrings.call),
                onPressed: () => LauncherUtils.call(job.contactPhone),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton.icon(
                style: FilledButton.styleFrom(backgroundColor: AppColors.whatsapp),
                icon: const Icon(Icons.chat),
                label: const Text(AppStrings.whatsapp),
                onPressed: () => LauncherUtils.whatsapp(job.contactPhone),
              ),
            ),
          ],
        ),
        gap,
      ],
      if (asWorker && job.status == JobStatus.pending) ...[
        FilledButton.icon(
          style: FilledButton.styleFrom(backgroundColor: AppColors.verified),
          icon: const Icon(Icons.check),
          label: const Text(AppStrings.acceptJob),
          onPressed: () => _setStatus(JobStatus.accepted),
        ),
        gap,
        OutlinedButton.icon(
          style: outlined.copyWith(foregroundColor: const WidgetStatePropertyAll(AppColors.error)),
          icon: const Icon(Icons.close),
          label: const Text(AppStrings.declineJob),
          onPressed: () => _setStatus(JobStatus.declined),
        ),
      ],
      if (job.status == JobStatus.accepted) ...[
        FilledButton.icon(
          icon: const Icon(Icons.task_alt),
          label: const Text(AppStrings.markDone),
          onPressed: () => _setStatus(JobStatus.completed),
        ),
        gap,
      ],
      if (!asWorker) ...[
        if (job.status == JobStatus.completed) ...[
          FilledButton.icon(
            icon: const Icon(Icons.rate_review_outlined),
            label: const Text(AppStrings.writeReview),
            onPressed: () {
              Navigator.pop(context);
              ref.invalidate(hasContactedProvider(job.workerId));
              context.push(Routes.writeReviewFor(job.workerId));
            },
          ),
          gap,
        ],
        OutlinedButton.icon(
          style: outlined,
          icon: const Icon(Icons.person_outline),
          label: const Text(AppStrings.openWorkerPage),
          onPressed: () {
            Navigator.pop(context);
            context.push(Routes.workerDetailsFor(job.workerId));
          },
        ),
        if (job.isOpen) ...[
          gap,
          TextButton.icon(
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            icon: const Icon(Icons.cancel_outlined),
            label: const Text(AppStrings.cancelRequest),
            onPressed: () => _setStatus(JobStatus.cancelled),
          ),
        ],
      ],
    ];
  }
}

class _JobPhoto extends ConsumerWidget {
  final String path;

  const _JobPhoto({required this.path});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final url = ref.watch(jobPhotoUrlProvider(path)).valueOrNull;
    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 8),
      child: Align(
        alignment: Alignment.centerLeft,
        child: url == null
            ? const SizedBox.square(dimension: 120, child: Center(child: CircularProgressIndicator()))
            : PhotoThumb(url: url, size: 120),
      ),
    );
  }
}
