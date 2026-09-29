import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/route_names.dart';
import '../../../core/strings/app_strings.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/error_messages.dart';
import '../../../core/utils/price_utils.dart';
import '../../../shared/models/worker_listing.dart';
import '../../../shared/models/worker_service.dart';
import '../../../shared/widgets/async_view.dart';
import '../../../shared/widgets/avatar_image.dart';
import '../../../shared/widgets/category_icon.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/info_note.dart';
import '../../../shared/widgets/photo_viewer.dart';
import '../../../shared/widgets/review_tile.dart';
import '../../../shared/widgets/section_header.dart';
import '../../../shared/widgets/verified_badge.dart';
import '../../../shared/widgets/worker_stats.dart';
import '../../admin/providers/admin_providers.dart';
import '../../admin/widgets/admin_review_card.dart';
import '../../auth/data/auth_repository.dart';
import '../../jobs/providers/job_providers.dart';
import '../../worker/providers/worker_providers.dart';
import '../data/directory_repository.dart';
import '../data/review_repository.dart';
import '../data/saved_workers_repository.dart';
import '../providers/worker_details_providers.dart';
import '../widgets/contact_buttons.dart';

/// C3 Worker details
/// Purpose: Give customers enough information to decide and make contact.
/// Backend: Reads worker_directory, worker_services, work_photos and reviews.
/// Done when: Call and WhatsApp buttons work on a real phone.
/// Customers can also save the worker, send a job request, and review them
/// once they've been in touch. Workers also open their own page from B5,
/// without contact, review or report, and reply to reviews there. Admins can
/// open workers awaiting approval too (from C2 or Settings), and approve or
/// reject them in the 'Admin check' card.
class WorkerDetailsScreen extends ConsumerWidget {
  final String workerId;

  const WorkerDetailsScreen({super.key, required this.workerId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final details = ref.watch(workerDetailsProvider(workerId));
    final isMe = ref.watch(authRepositoryProvider).userId == workerId;
    final phone = details.valueOrNull?.worker.whatsappNumber;

    return Scaffold(
      appBar: AppBar(
        actions: [if (!isMe && details.valueOrNull != null) _SaveButton(workerId: workerId)],
      ),
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
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                boxShadow: [
                  BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 24, offset: const Offset(0, -6)),
                ],
              ),
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
                  child: ContactButtons(workerId: workerId, phone: phone),
                ),
              ),
            ),
    );
  }
}

/// The heart: save the worker to call again.
class _SaveButton extends ConsumerStatefulWidget {
  final String workerId;

  const _SaveButton({required this.workerId});

  @override
  ConsumerState<_SaveButton> createState() => _SaveButtonState();
}

class _SaveButtonState extends ConsumerState<_SaveButton> {
  bool _saving = false;

  Future<void> _toggle(bool saved) async {
    setState(() => _saving = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(savedWorkersRepositoryProvider).setSaved(widget.workerId, saved: !saved);
      ref.invalidate(isSavedProvider(widget.workerId));
      ref.invalidate(savedWorkersProvider);
      messenger.showSnackBar(SnackBar(content: Text(saved ? AppStrings.workerUnsaved : AppStrings.workerSaved)));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(ErrorMessages.from(e))));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final saved = ref.watch(isSavedProvider(widget.workerId)).valueOrNull;
    return IconButton(
      tooltip: saved == true ? AppStrings.unsaveWorker : AppStrings.saveWorker,
      icon: Icon(saved == true ? Icons.favorite_rounded : Icons.favorite_border_rounded,
          color: saved == true ? const Color(0xFFD64545) : null),
      onPressed: saved == null || _saving ? null : () => _toggle(saved),
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
    final listed = worker.isApproved && worker.isActive;

    return RefreshIndicator(
      onRefresh: () => Future.wait([
        ref.refresh(workerDetailsProvider(worker.id).future),
        ref.refresh(workerReviewsProvider(worker.id).future),
        ref.refresh(workPhotosProvider(worker.id).future),
      ]),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          if (isMe) ...[
            const InfoNote(icon: Icons.visibility_outlined, text: AppStrings.yourPublicProfile),
            const SizedBox(height: 16),
          ] else if (ref.watch(isAdminProvider)) ...[
            AdminReviewCard(worker: worker),
            const SizedBox(height: 16),
          ],
          // Profile card: a strip in the brand colours behind the photo.
          Card(
            child: Stack(
              children: [
                const Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  height: 92,
                  child: DecoratedBox(decoration: BoxDecoration(gradient: AppColors.brandGradient)),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 36, 20, 22),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Center(
                        child: AvatarImage(url: worker.avatarUrl, name: worker.fullName, size: 112, ring: true),
                      ),
                      const SizedBox(height: 14),
                      Text(worker.fullName, textAlign: TextAlign.center, style: text.headlineSmall),
                      const SizedBox(height: 6),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.location_on_outlined, size: 18, color: muted),
                          const SizedBox(width: 4),
                          Flexible(child: Text(worker.location, style: TextStyle(color: muted))),
                        ],
                      ),
                      const SizedBox(height: 12),
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
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          WorkerStats(worker: worker),
          if (!worker.isAvailable) ...[
            const SizedBox(height: 12),
            const InfoNote(icon: Icons.schedule, text: AppStrings.notAvailableNow),
          ],
          if (!isMe && listed) ...[
            const SizedBox(height: 16),
            _JobRequestButton(worker: worker),
          ],
          if (bio.isNotEmpty) ...[
            const SizedBox(height: 28),
            const SectionHeader(AppStrings.about),
            const SizedBox(height: 10),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(bio, style: text.bodyLarge?.copyWith(color: AppColors.inkSoft)),
              ),
            ),
          ],
          _WorkPhotos(workerId: worker.id),
          const SizedBox(height: 28),
          const SectionHeader(AppStrings.services),
          const SizedBox(height: 10),
          _ServiceList(services: details.services),
          const SizedBox(height: 28),
          // Only workers customers can see can be reviewed or reported.
          _Reviews(workerId: worker.id, count: worker.reviewCount, isMe: isMe, canReview: !isMe && listed),
          if (!isMe && listed) ...[
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

/// 'Request a job' when the worker is taking work, or the customer's open
/// request to them (only one is allowed at a time).
class _JobRequestButton extends ConsumerWidget {
  final WorkerListing worker;

  const _JobRequestButton({required this.worker});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (ref.watch(openJobWithProvider(worker.id)) != null) {
      return OutlinedButton.icon(
        style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(54)),
        icon: const Icon(Icons.assignment_outlined),
        label: const Text(AppStrings.seeYourRequest),
        onPressed: () => context.push(Routes.jobs),
      );
    }
    if (!worker.isAvailable) return const SizedBox.shrink();
    return FilledButton.icon(
      style: FilledButton.styleFrom(
        elevation: 2,
        shadowColor: AppColors.primaryDeep.withValues(alpha: 0.4),
      ),
      icon: const Icon(Icons.assignment_add),
      label: const Text(AppStrings.requestJob),
      onPressed: () => context.push(Routes.requestJobFor(worker.id)),
    );
  }
}

/// Photos of past work, when there are any. Tap one to see it full size.
class _WorkPhotos extends ConsumerWidget {
  final String workerId;

  const _WorkPhotos({required this.workerId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final photos = ref.watch(workPhotosProvider(workerId)).valueOrNull ?? const [];
    if (photos.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 28),
        const SectionHeader(AppStrings.workPhotos),
        const SizedBox(height: 10),
        SizedBox(
          height: 128,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: photos.length,
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (context, i) => PhotoThumb(url: photos[i].url, size: 128),
          ),
        ),
      ],
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
            if (i > 0) const Divider(indent: 72, endIndent: 16),
            ListTile(
              leading: CategoryIcon(name: service.categoryIcon, size: 44),
              title: Text(service.categoryName ?? '', style: const TextStyle(fontWeight: FontWeight.w700)),
              subtitle: Text(
                PriceUtils.display(service.priceNote) ?? AppStrings.askForPrice,
                style: TextStyle(
                  color: service.priceNote == null ? AppColors.muted : AppColors.primaryDeep,
                  fontWeight: service.priceNote == null ? FontWeight.w400 : FontWeight.w600,
                ),
              ),
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
  final bool isMe; // the worker: can reply
  final bool canReview; // a customer, and the worker is listed

  const _Reviews({required this.workerId, required this.count, required this.isMe, required this.canReview});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reviews = ref.watch(workerReviewsProvider(workerId));
    final contacted = canReview && ref.watch(hasContactedProvider(workerId)).valueOrNull == true;
    final hasMyReview = contacted && ref.watch(myReviewProvider(workerId)).valueOrNull != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeader(
          '${AppStrings.reviews} ($count)',
          action: contacted
              ? TextButton.icon(
                  icon: const Icon(Icons.rate_review_outlined),
                  label: Text(hasMyReview ? AppStrings.editReview : AppStrings.writeReview),
                  onPressed: () => context.push(Routes.writeReviewFor(workerId)),
                )
              : null,
        ),
        if (canReview && !contacted) ...[
          const SizedBox(height: 8),
          const InfoNote(icon: Icons.rate_review_outlined, text: AppStrings.reviewAfterContact),
        ],
        const SizedBox(height: 10),
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
              : Card(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      children: [
                        for (final (i, review) in reviews.indexed) ...[
                          if (i > 0) const Divider(),
                          ReviewTile(
                            review: review,
                            onReply: isMe
                                ? () async {
                                    final saved = await replyToReview(context, review,
                                        (reply) => ref.read(reviewRepositoryProvider).replyToReview(review.id, reply));
                                    if (saved) ref.invalidate(workerReviewsProvider(workerId));
                                  }
                                : null,
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
        ),
      ],
    );
  }
}
