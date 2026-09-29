import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/route_names.dart';
import '../../../core/strings/app_strings.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/error_messages.dart';
import '../../../core/utils/price_utils.dart';
import '../../../shared/models/worker_listing.dart';
import '../../../shared/widgets/app_bar_logo.dart';
import '../../../shared/widgets/async_view.dart';
import '../../../shared/widgets/avatar_image.dart';
import '../../../shared/widgets/brand_panel.dart';
import '../../../shared/widgets/category_icon.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/icon_tile.dart';
import '../../../shared/widgets/review_tile.dart';
import '../../../shared/widgets/section_header.dart';
import '../../../shared/widgets/verified_badge.dart';
import '../../../shared/widgets/worker_stats.dart';
import '../../auth/data/auth_repository.dart';
import '../../customer/data/directory_repository.dart';
import '../../customer/data/review_repository.dart';
import '../../customer/providers/worker_details_providers.dart';
import '../../jobs/providers/job_providers.dart';
import '../../notifications/widgets/notifications_button.dart';
import '../../profile/widgets/settings_button.dart';
import '../data/worker_repository.dart';
import '../widgets/availability_switch.dart';

/// B5 Worker dashboard
/// Purpose: Home screen for approved workers.
/// Backend: Updates is_available; reads reviews and rating from worker_directory,
/// and job requests. Workers reply to reviews here.
/// Done when: Turning availability off shows 'Not available' to customers.
class WorkerDashboardScreen extends ConsumerWidget {
  const WorkerDashboardScreen({super.key});

  static const _recentReviews = 5;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final myId = ref.watch(authRepositoryProvider).userId ?? '';
    final details = ref.watch(workerDetailsProvider(myId));

    return Scaffold(
      appBar: AppBar(title: const AppBarLogo(), actions: const [NotificationsButton(), SettingsButton()]),
      body: SafeArea(
        child: AsyncView(
          value: details,
          onRetry: () => ref.invalidate(workerDetailsProvider(myId)),
          // Not approved any more: the team has changed their mind.
          data: (details) => details == null || !details.worker.isApproved
              ? EmptyState(
                  icon: Icons.visibility_off_outlined,
                  message: AppStrings.notListedNow,
                  actionLabel: AppStrings.seeMyStatus,
                  onAction: () => context.go(Routes.workerPending),
                )
              : RefreshIndicator(
                  onRefresh: () => Future.wait([
                    ref.refresh(workerDetailsProvider(myId).future),
                    ref.refresh(workerReviewsProvider(myId).future),
                    ref.refresh(myJobsProvider.future),
                  ]),
                  child: _Dashboard(details: details),
                ),
        ),
      ),
    );
  }
}

class _Dashboard extends ConsumerWidget {
  final WorkerDetails details;

  const _Dashboard({required this.details});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final worker = details.worker;
    final reviews = ref.watch(workerReviewsProvider(worker.id));
    final text = Theme.of(context).textTheme;
    final muted = TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant);

    Widget link(IconData icon, String label, VoidCallback onTap) => ListTile(
          leading: IconTile(icon: icon),
          title: Text(label),
          trailing: const Icon(Icons.chevron_right_rounded, color: AppColors.muted),
          onTap: onTap,
        );

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
      children: [
        BrandPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  AvatarImage(url: worker.avatarUrl, name: worker.fullName, size: 64, ring: true),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          AppStrings.greeting(worker.fullName),
                          style: text.titleLarge?.copyWith(fontWeight: FontWeight.w800, color: Colors.white),
                        ),
                        const SizedBox(height: 8),
                        // White behind the badge, so its green reads on the panel.
                        const DecoratedBox(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.all(Radius.circular(20)),
                          ),
                          child: VerifiedBadge(),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              WorkerStats(worker: worker, onBrand: true),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _Availability(worker: worker),
        const SizedBox(height: 12),
        const _JobRequestsCard(),
        const SizedBox(height: 28),
        SectionHeader(
          AppStrings.yourServices,
          action: TextButton(
            onPressed: () => context.push(Routes.workerServices),
            child: const Text(AppStrings.edit),
          ),
        ),
        const SizedBox(height: 6),
        Card(
          child: Column(
            children: [
              for (final (i, service) in details.services.indexed) ...[
                if (i > 0) const Divider(indent: 72, endIndent: 16),
                ListTile(
                  leading: CategoryIcon(name: service.categoryIcon, size: 44),
                  title: Text(service.categoryName ?? '', style: const TextStyle(fontWeight: FontWeight.w700)),
                  subtitle: Text(
                    PriceUtils.display(service.priceNote) ?? AppStrings.askForPrice,
                    style: service.priceNote == null
                        ? null
                        : const TextStyle(color: AppColors.primaryDeep, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),
        Card(
          child: Column(
            children: [
              link(Icons.person_outline_rounded, AppStrings.editProfile, () => context.push(Routes.workerSetup)),
              const Divider(indent: 70, endIndent: 16),
              link(Icons.photo_library_outlined, AppStrings.yourWorkPhotos, () => context.push(Routes.workPhotos)),
              const Divider(indent: 70, endIndent: 16),
              link(Icons.visibility_outlined, AppStrings.seePublicProfile,
                  () => context.push(Routes.workerDetailsFor(worker.id))),
            ],
          ),
        ),
        const SizedBox(height: 28),
        const SectionHeader(AppStrings.recentReviews),
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
                onPressed: () => ref.invalidate(workerReviewsProvider(worker.id)),
                child: const Text(AppStrings.retry),
              ),
            ],
          ),
          data: (reviews) => reviews.isEmpty
              ? Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text(AppStrings.noReviewsForWorker, style: muted),
                )
              : Card(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      children: [
                        for (final (i, review) in reviews.take(WorkerDashboardScreen._recentReviews).indexed) ...[
                          if (i > 0) const Divider(),
                          ReviewTile(
                            review: review,
                            onReply: () async {
                              final saved = await replyToReview(context, review,
                                  (reply) => ref.read(reviewRepositoryProvider).replyToReview(review.id, reply));
                              if (saved) ref.invalidate(workerReviewsProvider(worker.id));
                            },
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

/// Job requests from customers, with how many are waiting for an answer.
class _JobRequestsCard extends ConsumerWidget {
  const _JobRequestsCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final waiting = ref.watch(newJobCountProvider);
    return Card(
      color: waiting > 0 ? const Color(0xFFFFF8F1) : null,
      shape: waiting > 0
          ? RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: BorderSide(color: AppColors.primary.withValues(alpha: 0.4)),
            )
          : null,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        leading: Badge(
          isLabelVisible: waiting > 0,
          label: Text('$waiting'),
          child: const IconTile(icon: Icons.assignment_outlined, size: 44),
        ),
        title: const Text(AppStrings.jobRequests, style: TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Text(
          AppStrings.newJobRequests(waiting),
          style: waiting > 0 ? const TextStyle(color: AppColors.primaryDeep, fontWeight: FontWeight.w600) : null,
        ),
        trailing: const Icon(Icons.chevron_right_rounded, color: AppColors.muted),
        onTap: () => context.push(Routes.jobs),
      ),
    );
  }
}

/// The switch changes at once; it flips back if saving fails.
class _Availability extends ConsumerStatefulWidget {
  final WorkerListing worker;

  const _Availability({required this.worker});

  @override
  ConsumerState<_Availability> createState() => _AvailabilityState();
}

class _AvailabilityState extends ConsumerState<_Availability> {
  bool? _value;
  bool _saving = false;

  Future<void> _set(bool available) async {
    setState(() {
      _value = available;
      _saving = true;
    });
    try {
      await ref.read(workerRepositoryProvider).setAvailability(available);
      ref.invalidate(workerDetailsProvider(widget.worker.id));
    } catch (e) {
      if (!mounted) return;
      setState(() => _value = !available);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(ErrorMessages.from(e))));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AvailabilitySwitch(
      value: _value ?? widget.worker.isAvailable,
      onChanged: _saving ? null : _set,
    );
  }
}
