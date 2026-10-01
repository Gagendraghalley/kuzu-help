import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show PostgrestException;

import '../../../core/constants/app_constants.dart';
import '../../../core/strings/app_strings.dart';
import '../../../core/utils/bhutan_time.dart';
import '../../../core/utils/error_messages.dart';
import '../../../core/utils/phone_utils.dart';
import '../../../core/utils/text_utils.dart';
import '../../../shared/models/ground.dart';
import '../../../shared/widgets/form_error.dart';
import '../../../shared/widgets/info_note.dart';
import '../../../shared/widgets/primary_button.dart';
import '../../../shared/widgets/sheet_title.dart';
import '../data/booking_repository.dart';
import '../providers/booking_providers.dart';
import '../providers/venue_providers.dart';
import 'booking_summary.dart';
import 'day_strip.dart';
import 'slot_picker.dart';

/// The ground's manager books one of its free times for someone who called,
/// within the week ahead, confirmed at once; or, [regular], holds times
/// every week for someone who always plays then: one day or more a week
/// (e.g. Tuesday and Friday). Either way everyone sees the time taken, and
/// the name and phone go in the manager's records.
class PhoneBookingSheet extends ConsumerStatefulWidget {
  final String venueId;
  final Ground ground;
  final bool regular; // starts with 'Mark as regular' on

  const PhoneBookingSheet({super.key, required this.venueId, required this.ground, this.regular = false});

  @override
  ConsumerState<PhoneBookingSheet> createState() => _PhoneBookingSheetState();
}

class _PhoneBookingSheetState extends ConsumerState<PhoneBookingSheet> {
  final _formKey = GlobalKey<FormState>();
  late bool _regular = widget.regular;
  DateTime _day = BhutanTime.today();
  TimeSlot? _slot; // a booking: the one time
  final _weekly = <TimeSlot>[]; // regular: every time chosen, on any days

  /// Days from today to [weekday] (0 to 6), to list the weekly times in the
  /// order the day strip shows them.
  int _daysUntil(int weekday) => (weekday - BhutanTime.weekdayOf(BhutanTime.today())) % 7;

  /// Chooses a weekly time, or unchooses it. One that overlaps another
  /// chosen on the same day replaces it: they can't both be held.
  void _toggleWeekly(TimeSlot slot) => setState(() {
        if (!_weekly.remove(slot)) {
          _weekly
            ..removeWhere((s) => s.weekday == slot.weekday && s.startHour < slot.endHour && slot.startHour < s.endHour)
            ..add(slot)
            ..sort((a, b) {
              final days = _daysUntil(a.weekday) - _daysUntil(b.weekday);
              return days != 0 ? days : TimeSlot.byTime(a, b);
            });
        }
        _error = null;
      });

  void _setRegular(bool on) => setState(() {
        if (on) {
          _weekly
            ..clear()
            ..addAll([if (_slot case final slot?) slot]);
        } else {
          _slot = _weekly.where((s) => s.weekday == BhutanTime.weekdayOf(_day)).firstOrNull;
        }
        _regular = on;
        _error = null;
      });
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _team = TextEditingController();
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _team.dispose();
    super.dispose();
  }

  ({String groundId, DateTime day}) get _dayKey => (groundId: widget.ground.id, day: _day);

  Future<void> _book() async {
    if (_saving) return;
    final slot = _slot;
    final weekly = [..._weekly];
    final formOk = _formKey.currentState!.validate();
    if (_regular ? weekly.isEmpty : slot == null) {
      setState(() => _error = AppStrings.chooseATime);
      return;
    }
    if (!formOk) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final entered = _phone.text.orNull;
    final phone = entered == null ? null : PhoneUtils.toInternational(entered);
    final repo = ref.read(bookingRepositoryProvider);
    try {
      if (_regular) {
        await repo.addRegularBookings(
            groundId: widget.ground.id, slots: weekly, name: _name.text.trim(), phone: phone, team: _team.text.orNull);
        ref.invalidate(regularBookingsProvider(widget.ground.id));
        ref.invalidate(availabilityProvider); // those days, every week
      } else if (slot != null) {
        await repo.bookByPhone(
          groundId: widget.ground.id,
          start: BhutanTime.at(_day, slot.startHour),
          hours: slot.hours,
          name: _name.text.trim(),
          phone: phone,
          team: _team.text.orNull,
        );
        ref.invalidate(venueBookingsProvider(widget.venueId));
      }
      ref.invalidate(availabilityProvider(_dayKey));
      ref.invalidate(bookingRecordsProvider(widget.venueId));
      navigator.pop();
      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(SnackBar(
        content: Text(switch (weekly) {
          _ when !_regular => AppStrings.phoneBooked,
          [final one] => AppStrings.regularAdded(one.weekday, one.startHour, one.endHour),
          _ => AppStrings.regularsAdded([for (final s in weekly) AppStrings.everyWeekday(s.weekday, s.startHour, s.endHour)]),
        }),
      ));
    } catch (e) {
      if (!mounted) return;
      final taken = e is PostgrestException && e.code == '23P01';
      if (taken) ref.invalidate(availabilityProvider(_dayKey)); // show what's free now
      setState(() {
        if (taken) _slot = null; // the weekly times stay, to change the one that clashes
        _error = switch (e) {
          PostgrestException(code: '23P01') => _regular ? AppStrings.regularClash : AppStrings.slotTaken,
          PostgrestException(code: '22023') => AppStrings.timeNotBookable,
          _ => ErrorMessages.from(e),
        };
      });
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final slot = _slot;
    final today = BhutanTime.today();
    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(24, 0, 24, 16 + MediaQuery.viewInsetsOf(context).bottom),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SheetTitle(_regular ? AppStrings.addRegularBooking : AppStrings.addBooking),
              const SizedBox(height: 8),
              // Held every week instead: the switch below says how.
              if (!_regular) ...[
                const InfoNote(icon: Icons.phone_in_talk_outlined, text: AppStrings.phoneBookingHint),
                const SizedBox(height: 8),
              ],
              Card(
                child: SwitchListTile(
                  title: const Text(AppStrings.everyWeek),
                  subtitle: _regular ? const Text(AppStrings.regularTimesHint) : null,
                  value: _regular,
                  onChanged: _setRegular,
                ),
              ),
              const SizedBox(height: 16),
              DayStrip(
                selected: _day,
                // Days with a weekly time chosen.
                marked: {
                  if (_regular)
                    for (var i = 0; i < 7; i++)
                      if (_weekly.any((s) => s.weekday == BhutanTime.weekdayOf(today.add(Duration(days: i)))))
                        today.add(Duration(days: i)),
                },
                onSelected: (day) => setState(() {
                  _day = day;
                  _slot = null;
                  _error = null;
                }),
              ),
              const SizedBox(height: 16),
              SlotPicker(
                ground: widget.ground,
                day: _day,
                selected: _regular ? _weekly.toSet() : {if (slot != null) slot},
                onSelected: _regular
                    ? _toggleWeekly
                    : (slot) => setState(() {
                          _slot = slot;
                          _error = null;
                        }),
              ),
              if (_regular) ...[
                // Every time held for them, on whichever days: each can be taken off.
                for (final s in _weekly) ...[
                  const SizedBox(height: 12),
                  BookingSummary(
                    when: AppStrings.everyWeekday(s.weekday, s.startHour, s.endHour),
                    price: widget.ground.priceOf(s),
                    onRemove: () => _toggleWeekly(s),
                  ),
                ],
                if (_weekly.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Text(AppStrings.regularMoreDays,
                      style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
                ],
              ] else if (slot != null) ...[
                const SizedBox(height: 12),
                BookingSummary(
                  when: AppStrings.bookingTime(BhutanTime.at(_day, slot.startHour), BhutanTime.at(_day, slot.endHour)),
                  price: widget.ground.priceOf(slot),
                ),
              ],
              const SizedBox(height: 16),
              TextFormField(
                controller: _name,
                maxLength: 100,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(labelText: AppStrings.callerName),
                validator: (v) => (v?.trim() ?? '').isEmpty ? AppStrings.enterCallerName : null,
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _phone,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: AppStrings.callerPhone,
                  hintText: AppStrings.mobileHint,
                  prefixText: '${AppConstants.countryCode} ',
                ),
                validator: (v) =>
                    (v ?? '').trim().isEmpty || PhoneUtils.isValidMobile(v!) ? null : AppStrings.invalidMobile,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _team,
                maxLength: 60,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(labelText: AppStrings.teamName, hintText: AppStrings.teamNameHint),
              ),
              if (_error != null) ...[
                const SizedBox(height: 8),
                FormError(_error!),
              ],
              const SizedBox(height: 16),
              PrimaryButton(
                label: _regular ? AppStrings.addRegularBookings(_weekly.length) : AppStrings.bookThisTime,
                isLoading: _saving,
                onPressed: _book,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
