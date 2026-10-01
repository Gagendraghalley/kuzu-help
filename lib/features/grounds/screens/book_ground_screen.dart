import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show PostgrestException;

import '../../../core/constants/app_constants.dart';
import '../../../core/router/route_names.dart';
import '../../../core/strings/app_strings.dart';
import '../../../core/utils/bhutan_time.dart';
import '../../../core/utils/error_messages.dart';
import '../../../core/utils/phone_utils.dart';
import '../../../core/utils/text_utils.dart';
import '../../../shared/models/ground.dart';
import '../../../shared/models/profile.dart';
import '../../../shared/models/venue.dart';
import '../../../shared/widgets/async_view.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/form_error.dart';
import '../../../shared/widgets/icon_tile.dart';
import '../../../shared/widgets/info_note.dart';
import '../../../shared/widgets/primary_button.dart';
import '../../../shared/widgets/section_header.dart';
import '../../auth/data/auth_repository.dart';
import '../../auth/providers/auth_providers.dart';
import '../../profile/data/profile_repository.dart';
import '../../profile/providers/profile_providers.dart';
import '../data/booking_repository.dart';
import '../providers/booking_providers.dart';
import '../providers/venue_providers.dart';
import '../widgets/booking_summary.dart';
import '../widgets/day_strip.dart';
import '../widgets/slot_picker.dart';

/// Book a time (from a ground's page)
/// Purpose: Choose a day, then one of the ground's free times, and book it
/// in a few taps.
/// Visitors who haven't logged in see the free and taken times too, then
/// log in to book (and come back here).
/// Backend: get_ground_availability for the day's taken times; book_ground,
/// which works out the price and refuses a time someone else has taken or
/// that isn't one of the ground's times.
/// Done when: The venue's manager is notified, and the booking shows under My bookings.
class BookGroundScreen extends ConsumerWidget {
  final String venueId;
  final String groundId;

  const BookGroundScreen({super.key, required this.venueId, required this.groundId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final details = ref.watch(venueDetailsProvider(venueId));
    final loggedIn = ref.watch(authRepositoryProvider).isLoggedIn;
    final profile = loggedIn ? ref.watch(myProfileProvider).valueOrNull : null;

    return Scaffold(
      appBar: AppBar(title: const Text(AppStrings.bookGround)),
      body: SafeArea(
        child: AsyncView(
          value: details,
          onRetry: () => ref.invalidate(venueDetailsProvider(venueId)),
          data: (details) {
            final ground = details?.grounds.where((g) => g.id == groundId).firstOrNull;
            if (details == null || ground == null || !ground.isActive || !details.venue.isListed) {
              return const EmptyState(icon: Icons.event_busy_outlined, message: AppStrings.groundNotBookable);
            }
            return _BookingForm(venue: details.venue, ground: ground, loggedIn: loggedIn, profile: profile);
          },
        ),
      ),
    );
  }
}

class _BookingForm extends ConsumerStatefulWidget {
  final Venue venue;
  final Ground ground;
  final bool loggedIn; // false: a visitor, who sees the times and logs in to book
  final Profile? profile; // fills in the phone number

  const _BookingForm({required this.venue, required this.ground, required this.loggedIn, required this.profile});

  @override
  ConsumerState<_BookingForm> createState() => _BookingFormState();
}

class _BookingFormState extends ConsumerState<_BookingForm> {
  final _formKey = GlobalKey<FormState>();
  DateTime _day = BhutanTime.today();
  TimeSlot? _slot;
  String _payment = PaymentMethod.payAtVenue;
  final _team = TextEditingController();
  final _players = TextEditingController();
  late final _phone = TextEditingController(
    text: widget.profile?.phone?.replaceFirst(AppConstants.countryCode, ''),
  );
  final _paymentRef = TextEditingController();
  final _note = TextEditingController();
  bool _sending = false;
  String? _error;

  @override
  void dispose() {
    _team.dispose();
    _players.dispose();
    _phone.dispose();
    _paymentRef.dispose();
    _note.dispose();
    super.dispose();
  }

  ({String groundId, DateTime day}) get _dayKey => (groundId: widget.ground.id, day: _day);

  void _setDay(DateTime day) => setState(() {
        _day = day;
        _slot = null;
        _error = null;
      });

  Future<void> _book() async {
    if (_sending) return;
    final slot = _slot;
    final formOk = _formKey.currentState!.validate();
    if (slot == null) {
      setState(() => _error = AppStrings.chooseATime);
      return;
    }
    if (!formOk) return;
    setState(() {
      _sending = true;
      _error = null;
    });
    final bookedAtOnce = widget.venue.autoConfirm;
    try {
      await ref.read(bookingRepositoryProvider).book(
            groundId: widget.ground.id,
            start: BhutanTime.at(_day, slot.startHour),
            hours: slot.hours,
            phone: PhoneUtils.toInternational(_phone.text),
            team: _team.text.orNull,
            players: int.tryParse(_players.text.trim()),
            payment: _payment,
            paymentRef: _payment == PaymentMethod.payAtVenue ? null : _paymentRef.text.orNull,
            note: _note.text.orNull,
          );
      ref.invalidate(myBookingsProvider);
      ref.invalidate(availabilityProvider(_dayKey));
      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      context.pop();
      messenger.showSnackBar(
          SnackBar(content: Text(bookedAtOnce ? AppStrings.bookedNow : AppStrings.bookingRequestSent)));
    } catch (e) {
      if (!mounted) return;
      final taken = e is PostgrestException && e.code == '23P01';
      if (taken) ref.invalidate(availabilityProvider(_dayKey)); // show what's free now
      setState(() {
        if (taken) _slot = null;
        _error = switch (e) {
          PostgrestException(code: '23P01') => AppStrings.slotTaken,
          PostgrestException(code: '54000') => AppStrings.tooManyWaiting,
          PostgrestException(code: '42501') => AppStrings.groundNotBookable,
          PostgrestException(code: '22023') => AppStrings.timeNotBookable,
          _ => ErrorMessages.from(e),
        };
      });
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  /// A visitor: straight to signing up as a player ([signUp]; an email that
  /// has an account gets sports grounds added), or to logging in; once
  /// they're in, the splash brings them back here.
  void _continueToBook({required bool signUp}) {
    ref.read(afterLoginRouteProvider.notifier).state = Routes.bookGroundFor(widget.venue.id, widget.ground.id);
    ref.read(chosenRoleProvider.notifier).state = signUp ? UserRole.player : null;
    context.push(Routes.login);
  }

  /// Logged in without sports grounds (a customer, a worker): adds them to
  /// the account, and the booking form appears.
  Future<void> _addGrounds() async {
    setState(() {
      _sending = true;
      _error = null;
    });
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(profileRepositoryProvider).addRole(UserRole.player);
      ref.invalidate(myProfileProvider);
      messenger.showSnackBar(SnackBar(content: Text(AppStrings.serviceAdded(UserRole.player))));
    } catch (e) {
      if (mounted) setState(() => _error = ErrorMessages.from(e));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final venue = widget.venue;
    final ground = widget.ground;
    final slot = _slot;
    final paymentInfo = venue.paymentInfo?.trim() ?? '';
    // Sports grounds are their own service: an account without them adds
    // them first (the database checks too). Still loading: the form.
    final needsGrounds = widget.profile?.hasRole(UserRole.player) == false;
    final canBook = widget.loggedIn && !needsGrounds;

    return Form(
      key: _formKey,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                leading: const IconTile(icon: Icons.sports_soccer_rounded, size: 48),
                title: Text(venue.name, style: const TextStyle(fontWeight: FontWeight.w800)),
                subtitle: Text(AppStrings.sportLabel(ground.sport)),
              ),
            ),
            const SizedBox(height: 24),
            const SectionHeader(AppStrings.chooseDay),
            const SizedBox(height: 10),
            DayStrip(selected: _day, onSelected: _setDay),
            const SizedBox(height: 8),
            Text(AppStrings.bookUpToAWeek, style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
            const SizedBox(height: 24),
            const SectionHeader(AppStrings.chooseTime),
            const SizedBox(height: 10),
            SlotPicker(
              ground: ground,
              day: _day,
              selected: {if (slot != null) slot},
              onSelected: (slot) => setState(() {
                _slot = slot;
                _error = null;
              }),
            ),
            if (slot != null) ...[
              const SizedBox(height: 16),
              BookingSummary(
                when: AppStrings.bookingTime(BhutanTime.at(_day, slot.startHour), BhutanTime.at(_day, slot.endHour)),
                price: ground.priceOf(slot),
              ),
            ],
            // Visitors see the times, then log in to fill in the rest.
            if (canBook) ...[
              const SizedBox(height: 28),
              const SectionHeader(AppStrings.yourBooking),
              const SizedBox(height: 12),
              TextFormField(
                controller: _team,
                maxLength: 60,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(labelText: AppStrings.teamName, hintText: AppStrings.teamNameHint),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _players,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: AppStrings.playersCount),
                validator: (v) {
                  final text = v?.trim() ?? '';
                  if (text.isEmpty) return null;
                  final n = int.tryParse(text);
                  return n == null || n < 1 || n > 30 ? AppStrings.invalidPlayers : null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _phone,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: AppStrings.jobPhone,
                  hintText: AppStrings.mobileHint,
                  prefixText: '${AppConstants.countryCode} ',
                ),
                validator: (v) => PhoneUtils.isValidMobile(v ?? '') ? null : AppStrings.invalidMobile,
              ),
              const SizedBox(height: 20),
              Text(AppStrings.howWillYouPay, style: Theme.of(context).textTheme.labelLarge),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final method in PaymentMethod.all)
                    ChoiceChip(
                      label: Text(AppStrings.paymentLabel(method)),
                      selected: _payment == method,
                      onSelected: (_) => setState(() => _payment = method),
                    ),
                ],
              ),
              if (_payment != PaymentMethod.payAtVenue) ...[
                const SizedBox(height: 14),
                InfoNote(
                  icon: Icons.account_balance_outlined,
                  text: paymentInfo.isEmpty ? AppStrings.askVenueHowToPay : '${AppStrings.howToPayVenue}: $paymentInfo',
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _paymentRef,
                  maxLength: 60,
                  decoration: const InputDecoration(
                    labelText: AppStrings.journalNumber,
                    hintText: AppStrings.journalNumberHint,
                  ),
                ),
              ],
              const SizedBox(height: 16),
              TextFormField(
                controller: _note,
                minLines: 2,
                maxLines: 4,
                maxLength: 500,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: AppStrings.bookingNote,
                  hintText: AppStrings.bookingNoteHint,
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: 8),
            ] else
              const SizedBox(height: 28),
            InfoNote(
              icon: Icons.event_busy_outlined,
              text: [
                AppStrings.freeCancelNote(venue.freeCancelHours),
                venue.autoConfirm ? AppStrings.confirmedAtOnce : AppStrings.confirmedByVenue,
              ].join('\n\n'),
            ),
            if (_error != null) ...[
              const SizedBox(height: 16),
              FormError(_error!),
            ],
            const SizedBox(height: 20),
            if (canBook)
              PrimaryButton(
                label: !venue.autoConfirm
                    ? AppStrings.sendBookingRequest
                    : slot == null
                        ? AppStrings.book
                        : AppStrings.bookFor(ground.priceOf(slot)),
                isLoading: _sending,
                onPressed: _book,
              )
            else if (widget.loggedIn) ...[
              const InfoNote(icon: Icons.sports_soccer_rounded, text: AppStrings.addGroundsNote),
              const SizedBox(height: 16),
              PrimaryButton(label: AppStrings.addService(UserRole.player), isLoading: _sending, onPressed: _addGrounds),
            ] else ...[
              const InfoNote(icon: Icons.person_outline_rounded, text: AppStrings.logInToBookNote),
              const SizedBox(height: 16),
              PrimaryButton(label: AppStrings.createAccountToBook, onPressed: () => _continueToBook(signUp: true)),
              const SizedBox(height: 10),
              OutlinedButton(
                style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(54)),
                onPressed: () => _continueToBook(signUp: false),
                child: const Text(AppStrings.logInToBook),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
