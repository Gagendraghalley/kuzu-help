import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/route_names.dart';
import '../../../core/strings/app_strings.dart';
import '../../../core/utils/error_messages.dart';
import '../../../shared/models/worker_listing.dart';
import '../../../shared/widgets/app_bar_logo.dart';
import '../../../shared/widgets/async_view.dart';
import '../../../shared/widgets/avatar_image.dart';
import '../../../shared/widgets/category_icon.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/review_tile.dart';
import '../../../shared/widgets/section_header.dart';
import '../../../shared/widgets/verified_badge.dart';
import '../../../shared/widgets/worker_stats.dart';
import '../../auth/data/auth_repository.dart';
import '../../customer/data/directory_repository.dart';
import '../../customer/providers/worker_details_providers.dart';
import '../../notifications/widgets/notifications_button.dart';
import '../../profile/widgets/settings_button.dart';
import '../data/worker_repository.dart';
import '../widgets/availability_switch.dart';

/// B5 Worker dashboard
/// Purpose: Home screen for approved workers.
/// Backend: Updates is_available; reads reviews and rating from worker_directory.
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

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Row(
          children: [
            AvatarImage(url: worker.avatarUrl, name: worker.fullName, size: 64),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    AppStrings.greeting(worker.fullName),
                    style: text.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 6),
                  const VerifiedBadge(),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        _Availability(worker: worker),
        const SizedBox(height: 20),
        WorkerStats(worker: worker),
        const SizedBox(height: 28),
        SectionHeader(
          AppStrings.yourServices,
          action: TextButton(
            onPressed: () => context.push(Routes.workerServices),
            child: const Text(AppStrings.edit),
          ),
        ),
        const SizedBox(height: 8),
        Card(
          child: Column(
            children: [
              for (final (i, service) in details.services.indexed) ...[
                if (i > 0) const Divider(indent: 16, endIndent: 16),
                ListTile(
                  leading: CategoryIcon(name: service.categoryIcon, size: 40),
                  title: Text(service.categoryName ?? '', style: const TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Text(service.priceNote ?? AppStrings.askForPrice),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),
        Card(
          child: Column(
            children: [
              ListTile(
                leading: Icon(Icons.person_outline, color: Theme.of(context).colorScheme.primary),
                title: const Text(AppStrings.editProfile),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.push(Routes.workerSetup),
              ),
              const Divider(indent: 16, endIndent: 16),
              ListTile(
                leading: Icon(Icons.visibility_outlined, color: Theme.of(context).colorScheme.primary),
                title: const Text(AppStrings.seePublicProfile),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.push(Routes.workerDetailsFor(worker.id)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 28),
        const SectionHeader(AppStrings.recentReviews),
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
              : Column(
                  children: [
                    for (final (i, review) in reviews.take(WorkerDashboardScreen._recentReviews).indexed) ...[
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
