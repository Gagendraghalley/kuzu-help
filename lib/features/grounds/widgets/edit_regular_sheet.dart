import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show PostgrestException;

import '../../../core/constants/app_constants.dart';
import '../../../core/strings/app_strings.dart';
import '../../../core/utils/error_messages.dart';
import '../../../core/utils/phone_utils.dart';
import '../../../core/utils/text_utils.dart';
import '../../../shared/models/ground.dart';
import '../../../shared/models/regular_booking.dart';
import '../../../shared/widgets/form_error.dart';
import '../../../shared/widgets/info_note.dart';
import '../../../shared/widgets/primary_button.dart';
import '../../../shared/widgets/sheet_title.dart';
import '../data/booking_repository.dart';
import '../providers/booking_providers.dart';
import '../providers/venue_providers.dart';
import 'time_slots_editor.dart';

/// The ground's manager changes a regular booking: its day of the week and
/// time, or who has it. It goes on being held every week, as changed.
class EditRegularSheet extends ConsumerStatefulWidget {
  final String venueId;
  final Ground ground;
  final RegularBooking regular;

  const EditRegularSheet({super.key, required this.venueId, required this.ground, required this.regular});

  @override
  ConsumerState<EditRegularSheet> createState() => _EditRegularSheetState();
}

class _EditRegularSheetState extends ConsumerState<EditRegularSheet> {
  final _formKey = GlobalKey<FormState>();
  late int _weekday = widget.regular.weekday;
  late TimeSlot? _slot = widget.regular.slot;
  late final _name = TextEditingController(text: widget.regular.name);
  late final _phone = TextEditingController(text: widget.regular.phone?.replaceFirst(AppConstants.countryCode, ''));
  late final _team = TextEditingController(text: widget.regular.teamName);
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _team.dispose();
    super.dispose();
  }

  /// The ground's times on [weekday], and its own time even if the timings
  /// no longer have it.
  List<TimeSlot> _slotsOn(int weekday) {
    final own = widget.regular.slot;
    return {...widget.ground.slotsOnWeekday(weekday), if (own.weekday == weekday) own}.toList()..sort(TimeSlot.byTime);
  }

  Future<void> _save() async {
    if (_saving) return;
    final slot = _slot;
    final formOk = _formKey.currentState!.validate();
    if (slot == null) {
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
    try {
      await ref.read(bookingRepositoryProvider).updateRegularBooking(
            regularId: widget.regular.id,
            slot: slot,
            name: _name.text.trim(),
            phone: entered == null ? null : PhoneUtils.toInternational(entered),
            team: _team.text.orNull,
          );
      ref.invalidate(regularBookingsProvider(widget.ground.id));
      ref.invalidate(bookingRecordsProvider(widget.venueId));
      ref.invalidate(availabilityProvider); // the old day and the new, every week
      navigator.pop();
      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(
          SnackBar(content: Text(AppStrings.regularSaved(slot.weekday, slot.startHour, slot.endHour))));
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = switch (e) {
            PostgrestException(code: '23P01') => AppStrings.regularClash,
            PostgrestException(code: '22023') => AppStrings.regularNotATime,
            _ => ErrorMessages.from(e),
          });
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final regular = widget.regular;
    // Times the ground's other regular bookings hold: not free to move to.
    final others = [
      for (final r in ref.watch(regularBookingsProvider(widget.ground.id)).valueOrNull ?? const <RegularBooking>[])
        if (r.id != regular.id) r,
    ];
    RegularBooking? takenBy(TimeSlot slot) => others
        .where((r) => r.weekday == slot.weekday && r.startHour < slot.endHour && slot.startHour < r.endHour)
        .firstOrNull;
    final slots = _slotsOn(_weekday);

    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(24, 0, 24, 16 + MediaQuery.viewInsetsOf(context).bottom),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SheetTitle(AppStrings.editRegularTitle),
              const SizedBox(height: 8),
              InfoNote(icon: Icons.event_repeat_rounded, text: AppStrings.everyWeekHint(_weekday)),
              const SizedBox(height: 16),
              Text(AppStrings.chooseDay, style: text.titleSmall),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final weekday in TimeSlotsEditor.week)
                    ChoiceChip(
                      label: Text(AppStrings.weekdayName(weekday)),
                      selected: _weekday == weekday,
                      onSelected: _slotsOn(weekday).isEmpty
                          ? null // closed that day
                          : (_) => setState(() {
                                _weekday = weekday;
                                _slot = weekday == regular.weekday ? regular.slot : null;
                                _error = null;
                              }),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              Text(AppStrings.chooseTime, style: text.titleSmall),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final slot in slots)
                    ChoiceChip(
                      label: Text(switch (takenBy(slot)) {
                        final r? => AppStrings.takenSlot(slot.startHour, slot.endHour,
                            exact: r.slot == slot, confirmed: true, regular: true),
                        null => AppStrings.hoursRange(slot.startHour, slot.endHour),
                      }),
                      selected: _slot == slot,
                      onSelected: takenBy(slot) == null
                          ? (_) => setState(() {
                                _slot = slot;
                                _error = null;
                              })
                          : null,
                    ),
                ],
              ),
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
              PrimaryButton(label: AppStrings.saveRegular, isLoading: _saving, onPressed: _save),
            ],
          ),
        ),
      ),
    );
  }
}
