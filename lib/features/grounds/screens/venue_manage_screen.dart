import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show FunctionException, PostgrestException;

import '../../../core/router/route_names.dart';
import '../../../core/strings/app_strings.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/error_messages.dart';
import '../../../core/utils/phone_utils.dart';
import '../../../core/utils/text_utils.dart';
import '../../../shared/models/ground.dart';
import '../../../shared/models/regular_booking.dart';
import '../../../shared/models/venue.dart';
import '../../../shared/widgets/async_view.dart';
import '../../../shared/widgets/confirm_dialog.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/form_error.dart';
import '../../../shared/widgets/icon_tile.dart';
import '../../../shared/widgets/info_note.dart';
import '../../../shared/widgets/primary_button.dart';
import '../../../shared/widgets/section_header.dart';
import '../../../shared/widgets/sheet_title.dart';
import '../../admin/providers/admin_providers.dart';
import '../data/booking_repository.dart';
import '../data/venue_repository.dart';
import '../providers/booking_providers.dart';
import '../providers/venue_providers.dart';
import '../widgets/contact_row.dart';
import '../widgets/edit_regular_sheet.dart';
import '../widgets/fact_row.dart';
import '../widgets/manager_fields.dart';
import '../widgets/phone_booking_sheet.dart';
import '../widgets/status_pill.dart';
import '../widgets/subscription_card.dart';
import '../widgets/week_timings.dart';

/// Running a venue: its manager's (their home shows [VenueManagePanel]) and
/// admins'
/// Purpose: Bookings, grounds and details of one venue, in one place, with
/// its subscription. Admins also add, change or remove the person who runs it.
/// Backend: Reads venues and grounds; pauses bookings (venues.is_active);
/// set_venue_manager and the create-venue-manager Edge Function (admins).
/// Done when: The manager can answer bookings, keep grounds up to date and
/// pause the venue; an admin can give it a manager.
class VenueManageScreen extends ConsumerWidget {
  final String venueId;

  const VenueManageScreen({super.key, required this.venueId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final name = ref.watch(venueDetailsProvider(venueId)).valueOrNull?.venue.name;
    return Scaffold(
      appBar: AppBar(title: Text(name ?? AppStrings.myVenues)),
      body: SafeArea(child: VenueManagePanel(venueId: venueId)),
    );
  }
}

/// Everything about running one venue, scrollable, without its own app bar.
class VenueManagePanel extends ConsumerWidget {
  final String venueId;

  const VenueManagePanel({super.key, required this.venueId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AsyncView(
      value: ref.watch(venueDetailsProvider(venueId)),
      onRetry: () => ref.invalidate(venueDetailsProvider(venueId)),
      data: (details) => details == null
          ? const EmptyState(icon: Icons.stadium_outlined, message: AppStrings.venueNotListed)
          : RefreshIndicator(
              onRefresh: () => Future.wait([
                ref.refresh(venueDetailsProvider(venueId).future),
                ref.refresh(venueBookingsProvider(venueId).future),
              ]),
              child: _Manage(details: details),
            ),
    );
  }
}

class _Manage extends ConsumerWidget {
  final VenueDetails details;

  const _Manage({required this.details});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final venue = details.venue;
    final ground = details.grounds.firstOrNull; // its type, price and timings; none until they're added

    Widget link(IconData icon, String label, VoidCallback onTap) => ListTile(
          leading: IconTile(icon: icon),
          title: Text(label),
          trailing: const Icon(Icons.chevron_right_rounded, color: AppColors.muted),
          onTap: onTap,
        );

    // Customers see the ground once it has its type, price and some timings.
    final canBeBooked = ground != null && ground.isActive && ground.slots.isNotEmpty;
    // The subscription goes on top in its last days and once it has ended
    // (pay to stay listed); otherwise below everything that's used daily.
    final subscription = venue.subscription;
    final subscriptionOnTop = subscription != null && (subscription.isEnded() || subscription.endsSoon());

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
      children: [
        _StatusCard(venue: venue, canBeBooked: canBeBooked),
        if (subscriptionOnTop) ...[
          const SizedBox(height: 12),
          SubscriptionCard(venue: venue),
        ],
        if (ref.watch(isAdminProvider)) ...[
          const SizedBox(height: 12),
          _ManagerCard(venue: venue),
        ],
        const SizedBox(height: 12),
        _BookingsCard(venueId: venue.id),
        const SizedBox(height: 28),
        const SectionHeader(AppStrings.timings),
        const SizedBox(height: 10),
        _TimingsCard(venueId: venue.id, ground: ground),
        if (ground != null && ground.slots.isNotEmpty) ...[
          const SizedBox(height: 28),
          const SectionHeader(AppStrings.regularBookings),
          const SizedBox(height: 10),
          _RegularBookingsCard(venueId: venue.id, ground: ground),
        ],
        if (subscription != null && !subscriptionOnTop) ...[
          const SizedBox(height: 16),
          SubscriptionCard(venue: venue),
        ],
        const SizedBox(height: 16),
        Card(
          child: Column(
            children: [
              link(Icons.people_alt_outlined, AppStrings.bookingRecords,
                  () => context.push(Routes.venueRecordsFor(venue.id))),
              const Divider(indent: 70, endIndent: 16),
              link(Icons.edit_outlined, AppStrings.editVenue, () => context.push(Routes.editVenueFor(venue.id))),
              const Divider(indent: 70, endIndent: 16),
              link(Icons.visibility_outlined, AppStrings.seePublicVenue,
                  () => context.push(Routes.venueDetailsFor(venue.id))),
            ],
          ),
        ),
      ],
    );
  }
}

/// The ground's type, price and week of timings, and the way to change them.
/// Before it has a type and price, the way to add them (Edit ground).
class _TimingsCard extends StatelessWidget {
  final String venueId;
  final Ground? ground;

  const _TimingsCard({required this.venueId, required this.ground});

  @override
  Widget build(BuildContext context) {
    final ground = this.ground;
    final muted = TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: ground == null
              ? [
                  const InfoNote(icon: Icons.sports_soccer_rounded, text: AppStrings.typeAndPriceFirst),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    icon: const Icon(Icons.edit_outlined),
                    label: const Text(AppStrings.addTypeAndPrice),
                    onPressed: () => context.push(Routes.editVenueFor(venueId)),
                  ),
                ]
              : [
                  Text(
                    [
                      AppStrings.sportLabel(ground.sport),
                      AppStrings.groundPrice(ground.pricePerHourNu,
                          eveningPrice: ground.eveningPriceNu, eveningFrom: ground.eveningFromHour),
                    ].join(' · '),
                    style: muted,
                  ),
                  const SizedBox(height: 10),
                  if (ground.slots.isEmpty)
                    const InfoNote(icon: Icons.schedule_rounded, text: AppStrings.noTimingsYet)
                  else
                    WeekTimings(ground: ground),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    icon: const Icon(Icons.schedule_rounded),
                    label: const Text(AppStrings.setTimings),
                    onPressed: () => context.push(Routes.venueTimingsFor(venueId)),
                  ),
                ],
        ),
      ),
    );
  }
}

/// The times held every week for someone who always plays then, and the
/// way to add one.
class _RegularBookingsCard extends ConsumerWidget {
  final String venueId;
  final Ground ground;

  const _RegularBookingsCard({required this.venueId, required this.ground});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final regulars = ref.watch(regularBookingsProvider(ground.id));
    final muted = TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant);
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ...switch (regulars) {
              AsyncData(value: final list) when list.isNotEmpty => [
                  for (final r in list)
                    ListTile(
                      leading: const IconTile(icon: Icons.event_repeat_rounded),
                      title: Text(AppStrings.everyWeekday(r.weekday, r.startHour, r.endHour),
                          style: const TextStyle(fontWeight: FontWeight.w700)),
                      subtitle: Text([r.name, if (r.teamName case final team?) team].join(' · ')),
                      trailing: const Icon(Icons.chevron_right_rounded, color: AppColors.muted),
                      onTap: () async {
                        final edit = await showModalBottomSheet<bool>(
                          context: context,
                          showDragHandle: true,
                          builder: (_) => _RegularBookingSheet(venueId: venueId, regular: r),
                        );
                        if (edit != true || !context.mounted) return;
                        await showModalBottomSheet<void>(
                          context: context,
                          showDragHandle: true,
                          isScrollControlled: true,
                          useSafeArea: true,
                          builder: (_) => EditRegularSheet(venueId: venueId, ground: ground, regular: r),
                        );
                      },
                    ),
                ],
              AsyncData() => [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                    child: Text(AppStrings.noRegularBookings, style: muted),
                  ),
                ],
              AsyncError() => [
                  ListTile(
                    title: const Text(AppStrings.genericError),
                    trailing: TextButton(
                      onPressed: () => ref.invalidate(regularBookingsProvider(ground.id)),
                      child: const Text(AppStrings.retry),
                    ),
                  ),
                ],
              _ => [const Padding(padding: EdgeInsets.all(16), child: Center(child: CircularProgressIndicator()))],
            },
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: OutlinedButton.icon(
                icon: const Icon(Icons.add_rounded),
                label: const Text(AppStrings.addRegularBooking),
                onPressed: () => showModalBottomSheet<void>(
                  context: context,
                  showDragHandle: true,
                  isScrollControlled: true,
                  useSafeArea: true,
                  builder: (_) => PhoneBookingSheet(venueId: venueId, ground: ground, regular: true),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// One regular booking: who, how to reach them, and editing (it closes with
/// true, for the card to open [EditRegularSheet]) or removing it.
class _RegularBookingSheet extends ConsumerStatefulWidget {
  final String venueId;
  final RegularBooking regular;

  const _RegularBookingSheet({required this.venueId, required this.regular});

  @override
  ConsumerState<_RegularBookingSheet> createState() => _RegularBookingSheetState();
}

class _RegularBookingSheetState extends ConsumerState<_RegularBookingSheet> {
  bool _saving = false;

  Future<void> _stop() async {
    final ok = await confirm(
      context,
      title: AppStrings.stopRegularTitle,
      message: AppStrings.stopRegularMessage,
      confirmLabel: AppStrings.stopRegular,
      destructive: true,
    );
    if (!ok || !mounted) return;
    setState(() => _saving = true);
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final regular = widget.regular;
    try {
      await ref.read(bookingRepositoryProvider).removeRegularBooking(regular.id);
      ref.invalidate(regularBookingsProvider(regular.groundId));
      ref.invalidate(bookingRecordsProvider(widget.venueId));
      navigator.pop();
      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(const SnackBar(content: Text(AppStrings.regularStopped)));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(ErrorMessages.from(e))));
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.regular;
    final phone = r.phone;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SheetTitle(AppStrings.everyWeekday(r.weekday, r.startHour, r.endHour)),
            const SizedBox(height: 12),
            FactRow(icon: Icons.person_outline, label: AppStrings.callerName, value: r.name),
            if (r.teamName case final team?) FactRow(icon: Icons.groups_outlined, label: AppStrings.teamLabel, value: team),
            if (phone != null) FactRow(icon: Icons.phone_outlined, label: AppStrings.jobPhoneLabel, value: phone),
            const SizedBox(height: 16),
            if (_saving)
              const Center(child: CircularProgressIndicator())
            else ...[
              if (phone != null) ...[
                ContactRow(phone: phone),
                const SizedBox(height: 10),
              ],
              OutlinedButton.icon(
                icon: const Icon(Icons.edit_outlined),
                label: const Text(AppStrings.editRegular),
                onPressed: () => Navigator.of(context).pop(true),
              ),
              const SizedBox(height: 4),
              TextButton.icon(
                style: TextButton.styleFrom(foregroundColor: AppColors.error),
                icon: const Icon(Icons.event_busy_outlined),
                label: const Text(AppStrings.stopRegular),
                onPressed: _stop,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// The venue's name, where it stands, and the switch that pauses bookings.
class _StatusCard extends ConsumerStatefulWidget {
  final Venue venue;
  final bool canBeBooked; // false: customers can't see it yet, even when it's taking bookings

  const _StatusCard({required this.venue, required this.canBeBooked});

  @override
  ConsumerState<_StatusCard> createState() => _StatusCardState();
}

class _StatusCardState extends ConsumerState<_StatusCard> {
  bool _saving = false;

  Future<void> _setActive(bool active) async {
    setState(() => _saving = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(venueRepositoryProvider).setVenueActive(widget.venue.id, active);
      ref.invalidate(venueDetailsProvider(widget.venue.id));
      ref.invalidate(myVenuesProvider);
      ref.invalidate(allVenuesProvider);
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(ErrorMessages.from(e))));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final venue = widget.venue;
    final text = Theme.of(context).textTheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const IconTile(icon: Icons.stadium_outlined, size: 44),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(venue.name, style: text.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                      const SizedBox(height: 4),
                      if (venue.isListed && !widget.canBeBooked)
                        const StatusPill(label: AppStrings.notVisibleYet, color: AppColors.unavailable)
                      else
                        VenueStatusPill(venue: venue),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text(AppStrings.takingBookings),
              subtitle: Text(!venue.hasManager
                  ? AppStrings.noManagerYet
                  : venue.subscriptionEnded
                      ? AppStrings.subscriptionEndedHint
                      : !venue.isActive
                          ? AppStrings.pausedHint
                          : widget.canBeBooked
                              ? AppStrings.takingBookingsHint
                              : AppStrings.notVisibleNoGrounds),
              value: venue.isActive,
              onChanged: _saving ? null : _setActive,
            ),
          ],
        ),
      ),
    );
  }
}

/// Admins: who runs the venue, and adding, changing or removing them.
class _ManagerCard extends ConsumerStatefulWidget {
  final Venue venue;

  const _ManagerCard({required this.venue});

  @override
  ConsumerState<_ManagerCard> createState() => _ManagerCardState();
}

class _ManagerCardState extends ConsumerState<_ManagerCard> {
  bool _saving = false;

  Future<void> _remove() async {
    final ok = await confirm(
      context,
      title: AppStrings.removeManagerTitle,
      message: AppStrings.removeManagerMessage,
      confirmLabel: AppStrings.removeManager,
      destructive: true,
    );
    if (!ok || !mounted) return;
    setState(() => _saving = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(venueRepositoryProvider).setVenueManager(widget.venue.id, null);
      ref.invalidate(venueDetailsProvider(widget.venue.id));
      ref.invalidate(allVenuesProvider);
      messenger.showSnackBar(const SnackBar(content: Text(AppStrings.managerRemoved)));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(ErrorMessages.from(e))));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final venue = widget.venue;
    final muted = TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant);
    final details = [venue.managerEmail, venue.managerPhone].where((part) => part != null && part.isNotEmpty);

    return Card(
      color: const Color(0xFFFFF8F1),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: AppColors.primary.withValues(alpha: 0.35)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Row(
              children: [
                IconTile(icon: Icons.manage_accounts_outlined, size: 36),
                SizedBox(width: 12),
                Expanded(child: SectionHeader(AppStrings.groundManager)),
              ],
            ),
            const SizedBox(height: 10),
            if (!venue.hasManager)
              const Text(AppStrings.noManagerYet, style: TextStyle(color: AppColors.inkSoft))
            else ...[
              Wrap(
                spacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(venue.managerName ?? '', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                  if (!venue.managerActive) const StatusPill(label: AppStrings.deactivated, color: AppColors.error),
                ],
              ),
              if (details.isNotEmpty) Text(details.join(' · '), style: muted),
            ],
            const SizedBox(height: 14),
            if (_saving)
              const Center(child: CircularProgressIndicator())
            else ...[
              FilledButton.icon(
                icon: const Icon(Icons.person_add_alt_1_outlined),
                label: Text(venue.hasManager ? AppStrings.changeManager : AppStrings.addManager),
                onPressed: () => showModalBottomSheet<void>(
                  context: context,
                  showDragHandle: true,
                  isScrollControlled: true,
                  useSafeArea: true,
                  builder: (_) => _ManagerSheet(venueId: venue.id),
                ),
              ),
              if (venue.hasManager)
                TextButton.icon(
                  style: TextButton.styleFrom(foregroundColor: AppColors.error),
                  icon: const Icon(Icons.person_remove_outlined),
                  label: const Text(AppStrings.removeManager),
                  onPressed: _remove,
                ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Changing the manager: the new one's name, email and phone. Their account
/// is made (or found, when the email has one), then given the venue.
class _ManagerSheet extends ConsumerStatefulWidget {
  final String venueId;

  const _ManagerSheet({required this.venueId});

  @override
  ConsumerState<_ManagerSheet> createState() => _ManagerSheetState();
}

class _ManagerSheetState extends ConsumerState<_ManagerSheet> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _phone.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving || !_formKey.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    final repo = ref.read(venueRepositoryProvider);
    final name = _name.text.trim();
    final email = _email.text.trim().toLowerCase();
    final phone = _phone.text.orNull;
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    try {
      final account = await repo.createManagerAccount(
        email: email,
        fullName: name,
        phone: phone == null ? null : PhoneUtils.toInternational(phone),
      );
      await repo.setVenueManager(widget.venueId, account.userId);
      ref.invalidate(venueDetailsProvider(widget.venueId));
      ref.invalidate(allVenuesProvider);
      navigator.pop();
      // Straight away, not after 'Venue added' (it has what to tell them).
      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(SnackBar(
        duration: const Duration(seconds: 8),
        content: Text(AppStrings.managerAdded(name, email, created: account.created)),
      ));
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = switch (e) {
            PostgrestException(code: '22023') => AppStrings.managerNotAllowed,
            FunctionException(status: 404) => AppStrings.managerSetupMissing,
            _ => ErrorMessages.from(e),
          });
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(24, 0, 24, 16 + MediaQuery.viewInsetsOf(context).bottom),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SheetTitle(AppStrings.groundManager),
              const SizedBox(height: 8),
              ManagerFields(name: _name, email: _email, phone: _phone),
              if (_error != null) ...[
                const SizedBox(height: 12),
                FormError(_error!),
              ],
              const SizedBox(height: 20),
              PrimaryButton(label: AppStrings.saveManager, isLoading: _saving, onPressed: _save),
            ],
          ),
        ),
      ),
    );
  }
}

/// Bookings at the venue, with how many requests wait for an answer.
class _BookingsCard extends ConsumerWidget {
  final String venueId;

  const _BookingsCard({required this.venueId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final waiting = ref.watch(waitingBookingCountProvider(venueId));
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
          child: const IconTile(icon: Icons.event_note_outlined, size: 44),
        ),
        title: const Text(AppStrings.bookings, style: TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Text(
          AppStrings.requestsToAnswer(waiting),
          style: waiting > 0 ? const TextStyle(color: AppColors.primaryDeep, fontWeight: FontWeight.w600) : null,
        ),
        trailing: const Icon(Icons.chevron_right_rounded, color: AppColors.muted),
        onTap: () => context.push(Routes.venueBookingsFor(venueId)),
      ),
    );
  }
}
