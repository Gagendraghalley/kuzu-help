import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/route_names.dart';
import '../../../core/strings/app_strings.dart';
import '../../../shared/models/worker_service.dart';
import '../../../shared/widgets/async_view.dart';
import '../../../shared/widgets/avatar_image.dart';
import '../../../shared/widgets/category_icon.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/info_note.dart';
import '../../../shared/widgets/review_tile.dart';
import '../../../shared/widgets/section_header.dart';
import '../../../shared/widgets/verified_badge.dart';
import '../../../shared/widgets/worker_stats.dart';
import '../../admin/providers/admin_providers.dart';
import '../../admin/widgets/admin_review_card.dart';
import '../../auth/data/auth_repository.dart';
import '../data/directory_repository.dart';
import '../providers/worker_details_providers.dart';
import '../widgets/contact_buttons.dart';

/// C3 Worker details
/// Purpose: Give customers enough information to decide and make contact.
/// Backend: Reads worker_directory, worker_services and reviews.
/// Done when: Call and WhatsApp buttons work on a real phone.
/// Workers also open their own page from B5, without contact, review or report.
/// Admins can open workers awaiting approval too (from C2 or Settings), and
/// approve or reject them in the 'Admin check' card.
class WorkerDetailsScreen extends ConsumerWidget {
  final String workerId;

  const WorkerDetailsScreen({super.key, required this.workerId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final details = ref.watch(workerDetailsProvider(workerId));
    final isMe = ref.watch(authRepositoryProvider).userId == workerId;
    final phone = details.valueOrNull?.worker.whatsappNumber;

    return Scaffold(
      appBar: AppBar(),
      body: AsyncView(
        value: details,
        onRetry: () => ref.invalidate(workerDetailsProvider(workerId)),
        data: (details) => details == null
            ? const EmptyState(icon: Icons.person_off_outlined, message: AppStrings.workerNotListed)
            : _Details(details: details, isMe: isMe),
      ),
      bottomNavigationBar: phone == null || isMe
          ? null
          : DecoratedBox(
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border(top: BorderSide(color: Theme.of(context).colorScheme.outlineVariant)),
              ),
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                  child: ContactButtons(workerId: workerId, phone: phone),
                ),
              ),
            ),
    );
  }
}

class _Details extends ConsumerWidget {
  final WorkerDetails details;
  final bool isMe;

  const _Details({required this.details, required this.isMe});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final worker = details.worker;
    final bio = worker.bio?.trim() ?? '';
    final text = Theme.of(context).textTheme;
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;

    return RefreshIndicator(
      onRefresh: () => Future.wait([
        ref.refresh(workerDetailsProvider(worker.id).future),
        ref.refresh(workerReviewsProvider(worker.id).future),
      ]),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          if (isMe) ...[
            const InfoNote(icon: Icons.visibility_outlined, text: AppStrings.yourPublicProfile),
            const SizedBox(height: 20),
          ] else if (ref.watch(isAdminProvider)) ...[
            AdminReviewCard(worker: worker),
            const SizedBox(height: 20),
          ],
          Center(child: AvatarImage(url: worker.avatarUrl, name: worker.fullName, size: 112)),
          const SizedBox(height: 12),
          Text(
            worker.fullName,
            textAlign: TextAlign.center,
            style: text.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: [
              if (!worker.isActive) const DeactivatedBadge(),
              VerifiedBadge(status: worker.verificationStatus),
              AvailabilityLabel(isAvailable: worker.isAvailable),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.location_on_outlined, size: 18, color: muted),
              const SizedBox(width: 4),
              Flexible(child: Text(worker.location, style: TextStyle(color: muted))),
            ],
          ),
          const SizedBox(height: 20),
          WorkerStats(worker: worker),
          if (!worker.isAvailable) ...[
            const SizedBox(height: 12),
            const InfoNote(icon: Icons.schedule, text: AppStrings.notAvailableNow),
          ],
          if (bio.isNotEmpty) ...[
            const SizedBox(height: 24),
            const SectionHeader(AppStrings.about),
            const SizedBox(height: 8),
            Text(bio, style: text.bodyLarge),
          ],
          const SizedBox(height: 24),
          const SectionHeader(AppStrings.services),
          const SizedBox(height: 8),
          _ServiceList(services: details.services),
          const SizedBox(height: 24),
          // Only workers customers can see can be reviewed or reported.
          _Reviews(
            workerId: worker.id,
            count: worker.reviewCount,
            canReview: !isMe && worker.isApproved && worker.isActive,
          ),
          if (!isMe && worker.isApproved && worker.isActive) ...[
            const SizedBox(height: 16),
            Center(
              child: TextButton.icon(
                icon: const Icon(Icons.flag_outlined),
                label: const Text(AppStrings.reportWorker),
                style: TextButton.styleFrom(foregroundColor: muted),
                onPressed: () => context.push(Routes.reportWorkerFor(worker.id)),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ServiceList extends StatelessWidget {
  final List<WorkerService> services;

  const _ServiceList({required this.services});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Column(
        children: [
          for (final (i, service) in services.indexed) ...[
            if (i > 0) const Divider(indent: 16, endIndent: 16),
            ListTile(
              leading: CategoryIcon(name: service.categoryIcon, size: 40),
              title: Text(service.categoryName ?? '', style: const TextStyle(fontWeight: FontWeight.w600)),
              subtitle: Text(service.priceNote ?? AppStrings.askForPrice),
            ),
          ],
        ],
      ),
    );
  }
}

class _Reviews extends ConsumerWidget {
  final String workerId;
  final int count;
  final bool canReview;

  const _Reviews({required this.workerId, required this.count, required this.canReview});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reviews = ref.watch(workerReviewsProvider(workerId));
    final hasMyReview = canReview && ref.watch(myReviewProvider(workerId)).valueOrNull != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeader(
          '${AppStrings.reviews} ($count)',
          action: canReview
              ? TextButton.icon(
                  icon: const Icon(Icons.rate_review_outlined),
                  label: Text(hasMyReview ? AppStrings.editReview : AppStrings.writeReview),
                  onPressed: () => context.push(Routes.writeReviewFor(workerId)),
                )
              : null,
        ),
        reviews.when(
          loading: () => const Padding(
            padding: EdgeInsets.all(16),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (_, __) => Row(
            children: [
              const Expanded(child: Text(AppStrings.genericError)),
              TextButton(
                onPressed: () => ref.invalidate(workerReviewsProvider(workerId)),
                child: const Text(AppStrings.retry),
              ),
            ],
          ),
          data: (reviews) => reviews.isEmpty
              ? Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    canReview ? AppStrings.noReviewsYet : AppStrings.noReviewsForWorker,
                    style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
                  ),
                )
              : Column(
                  children: [
                    for (final (i, review) in reviews.indexed) ...[
                      if (i > 0) const Divider(),
                      ReviewTile(review: review),
                    ],
                  ],
                ),
        ),
      ],
    );
  }
}
