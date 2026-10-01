import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show FunctionException, PostgrestException;

import '../../../core/constants/app_constants.dart';
import '../../../core/router/route_names.dart';
import '../../../core/strings/app_strings.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/error_messages.dart';
import '../../../core/utils/phone_utils.dart';
import '../../../core/utils/price_utils.dart';
import '../../../core/utils/text_utils.dart';
import '../../../shared/models/ground.dart';
import '../../../shared/models/venue.dart';
import '../../../shared/widgets/async_view.dart';
import '../../../shared/widgets/dzongkhag_field.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/form_error.dart';
import '../../../shared/widgets/info_note.dart';
import '../../../shared/widgets/photo_picker.dart';
import '../../../shared/widgets/primary_button.dart';
import '../../../shared/widgets/section_header.dart';
import '../../profile/providers/profile_providers.dart';
import '../data/venue_repository.dart';
import '../providers/venue_providers.dart';
import '../widgets/manager_fields.dart';
import '../widgets/week_timings.dart';

/// Register a venue with its manager (admins), or edit one (its manager,
/// and admins)
/// Purpose: What customers see about a venue, how it takes bookings, and,
/// when it's new, the one person who runs it.
/// Backend: Uploads the cover photo to venue-photos. New: makes (or finds)
/// the manager's account with the create-venue-manager Edge Function, then
/// add_venue saves the venue and its manager together. Editing updates the
/// venues row.
/// Both include the ground's type and price (a grounds row: added with
/// the venue, or the first time they're saved); editing also shows its
/// timings, with the way to set them.
/// Done when: A new venue opens ready for its grounds, and its manager can
/// log in to run it.
class VenueFormScreen extends ConsumerWidget {
  final String? venueId; // null: a new venue

  const VenueFormScreen({super.key, this.venueId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final venueId = this.venueId;
    return Scaffold(
      appBar: AppBar(title: Text(venueId == null ? AppStrings.addVenue : AppStrings.editVenue)),
      body: SafeArea(
        child: venueId == null
            ? _VenueForm(existing: null, ownDzongkhag: ref.watch(myProfileProvider).valueOrNull?.dzongkhag)
            : AsyncView(
                value: ref.watch(venueDetailsProvider(venueId)),
                onRetry: () => ref.invalidate(venueDetailsProvider(venueId)),
                data: (details) => details == null
                    ? const EmptyState(icon: Icons.stadium_outlined, message: AppStrings.venueNotListed)
                    : _VenueForm(existing: details.venue, ground: details.grounds.firstOrNull),
              ),
      ),
    );
  }
}

class _VenueForm extends ConsumerStatefulWidget {
  final Venue? existing;
  final Ground? ground; // its type, price and timings, once it has them
  final String? ownDzongkhag; // a new venue starts in the admin's dzongkhag

  const _VenueForm({required this.existing, this.ground, this.ownDzongkhag});

  @override
  ConsumerState<_VenueForm> createState() => _VenueFormState();
}

class _VenueFormState extends ConsumerState<_VenueForm> {
  static const _cancelOptions = [0, 2, 6, 12, 24, 48];

  final _formKey = GlobalKey<FormState>();
  late final Venue? _venue = widget.existing;
  late final _name = TextEditingController(text: _venue?.name);
  late String? _dzongkhag = _venue?.dzongkhag ?? widget.ownDzongkhag;
  late final _town = TextEditingController(text: _venue?.town);
  late final _address = TextEditingController(text: _venue?.address);
  late final _phone = TextEditingController(text: _venue?.phone.replaceFirst(AppConstants.countryCode, ''));
  late final _whatsapp =
      TextEditingController(text: _venue?.whatsappNumber?.replaceFirst(AppConstants.countryCode, ''));
  late final _about = TextEditingController(text: _venue?.description);
  late bool _autoConfirm = _venue?.autoConfirm ?? false;
  late int _freeCancelHours = _venue?.freeCancelHours ?? 24;
  late final _policy = TextEditingController(text: _venue?.cancellationPolicy);
  late final _paymentInfo = TextEditingController(text: _venue?.paymentInfo);
  // Type and price (the grounds row).
  late final Ground? _ground = widget.ground;
  late String _sport = _ground?.sport ?? Sport.futsal;
  late final _format = TextEditingController(text: _ground?.format);
  late final _surface = TextEditingController(text: _ground?.surface);
  late bool _indoor = _ground?.isIndoor ?? false;
  late bool _floodlights = _ground?.hasFloodlights ?? true;
  late final _price = TextEditingController(text: _ground?.pricePerHourNu.toString());
  // Usually one price all day; some grounds charge more at night, for the lights.
  late bool _nightPrice = _ground?.eveningPriceNu != null;
  late final _eveningPrice = TextEditingController(text: _ground?.eveningPriceNu?.toString());
  late int _eveningFrom = _ground?.eveningFromHour ?? 18;
  // The manager, when registering a new venue.
  final _managerName = TextEditingController();
  final _managerEmail = TextEditingController();
  final _managerPhone = TextEditingController();
  Uint8List? _cover;
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    for (final c in [
      _name, _town, _address, _phone, _whatsapp, _about, _policy, _paymentInfo, //
      _format, _surface, _price, _eveningPrice, _managerName, _managerEmail, _managerPhone,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  static String? _priceError(String? value, {bool optional = false}) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return optional ? null : AppStrings.enterPrice;
    final price = int.tryParse(text);
    return price == null || price < 1 || price > 100000 ? AppStrings.enterPrice : null;
  }

  Future<void> _save() async {
    if (_saving) return;
    if (!_formKey.currentState!.validate()) return;

    final whatsapp = _whatsapp.text.orNull;
    final draft = VenueDraft(
      name: _name.text.trim(),
      dzongkhag: _dzongkhag!,
      town: _town.text.orNull,
      address: _address.text.orNull,
      phone: PhoneUtils.toInternational(_phone.text),
      whatsappNumber: whatsapp == null ? null : PhoneUtils.toInternational(whatsapp),
      description: _about.text.orNull,
      autoConfirm: _autoConfirm,
      freeCancelHours: _freeCancelHours,
      cancellationPolicy: _policy.text.orNull,
      paymentInfo: _paymentInfo.text.orNull,
    );
    final ground = GroundDraft(
      id: _ground?.id,
      name: draft.name,
      sport: _sport,
      format: _format.text.orNull,
      surface: _surface.text.orNull,
      isIndoor: _indoor,
      hasFloodlights: _floodlights,
      pricePerHourNu: int.parse(_price.text.trim()),
      eveningPriceNu: _nightPrice ? int.parse(_eveningPrice.text.trim()) : null,
      eveningFromHour: _eveningFrom,
    );
    setState(() {
      _saving = true;
      _error = null;
    });
    final repo = ref.read(venueRepositoryProvider);
    try {
      final venue = _venue;
      if (venue == null) {
        final managerName = _managerName.text.trim();
        final managerEmail = _managerEmail.text.trim().toLowerCase();
        final managerPhone = _managerPhone.text.orNull;
        final account = await repo.createManagerAccount(
          email: managerEmail,
          fullName: managerName,
          phone: managerPhone == null ? null : PhoneUtils.toInternational(managerPhone),
        );
        final id = await repo.addVenue(draft, managerId: account.userId, ground: ground, cover: _cover);
        ref.invalidate(allVenuesProvider);
        if (!mounted) return;
        final messenger = ScaffoldMessenger.of(context);
        // On to the venue itself, to add its grounds.
        context.pushReplacement(Routes.venueManageFor(id));
        messenger.showSnackBar(SnackBar(
          duration: const Duration(seconds: 8),
          content: Text(AppStrings.venueRegistered(draft.name, managerName, managerEmail, created: account.created)),
        ));
      } else {
        await repo.updateVenue(venue.id, draft, cover: _cover);
        await repo.saveGround(venue.id, ground);
        ref.invalidate(venuesProvider);
        ref.invalidate(myVenuesProvider);
        ref.invalidate(allVenuesProvider);
        ref.invalidate(venueDetailsProvider(venue.id));
        if (!mounted) return;
        final messenger = ScaffoldMessenger.of(context);
        context.pop();
        messenger.showSnackBar(const SnackBar(content: Text(AppStrings.venueSaved)));
      }
    } catch (e) {
      if (mounted) {
        setState(() => _error = switch (e) {
              PostgrestException(code: '22023') => AppStrings.managerNotAllowed,
              FunctionException(status: 404) => AppStrings.managerSetupMissing,
              _ => ErrorMessages.from(e),
            });
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isNew = _venue == null;
    final cover = _cover;
    final coverUrl = _venue?.coverUrl;

    return Form(
      key: _formKey,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _PhotoCard(
              title: AppStrings.coverPhoto,
              hint: AppStrings.coverPhotoHint,
              icon: Icons.add_a_photo_outlined,
              preview: cover != null
                  ? Image.memory(cover, fit: BoxFit.cover)
                  : coverUrl != null
                      ? Image.network(coverUrl, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const SizedBox())
                      : null,
              onTap: () async {
                final picked = await pickPhoto(context);
                if (picked != null) setState(() => _cover = picked);
              },
            ),
            const SizedBox(height: 20),
            TextFormField(
              controller: _name,
              maxLength: 80,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(labelText: AppStrings.venueName, hintText: AppStrings.venueNameHint),
              validator: (v) => (v?.trim().length ?? 0) < 2 ? AppStrings.enterVenueName : null,
            ),
            const SizedBox(height: 8),
            DzongkhagField(
              initialValue: _dzongkhag,
              required: true,
              onChanged: (value) => setState(() => _dzongkhag = value),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _town,
              maxLength: 80,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(labelText: AppStrings.town),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _address,
              maxLength: 200,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(labelText: AppStrings.venueAddress, hintText: AppStrings.venueAddressHint),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _phone,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: AppStrings.venuePhone,
                hintText: AppStrings.mobileHint,
                prefixText: '${AppConstants.countryCode} ',
              ),
              validator: (v) => PhoneUtils.isValidMobile(v ?? '') ? null : AppStrings.invalidMobile,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _whatsapp,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: AppStrings.venueWhatsapp,
                hintText: AppStrings.mobileHint,
                prefixText: '${AppConstants.countryCode} ',
              ),
              validator: (v) =>
                  (v ?? '').trim().isEmpty || PhoneUtils.isValidMobile(v!) ? null : AppStrings.invalidMobile,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _about,
              minLines: 3,
              maxLines: 6,
              maxLength: 1000,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: AppStrings.venueAbout,
                hintText: AppStrings.venueAboutHint,
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 20),
            const SectionHeader(AppStrings.typeAndPrice),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              initialValue: _sport,
              icon: const Icon(Icons.keyboard_arrow_down_rounded),
              borderRadius: BorderRadius.circular(16),
              dropdownColor: Colors.white,
              decoration: const InputDecoration(labelText: AppStrings.sport),
              items: [for (final s in Sport.all) DropdownMenuItem(value: s, child: Text(AppStrings.sportLabel(s)))],
              onChanged: (s) => setState(() => _sport = s ?? Sport.futsal),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _format,
              maxLength: 40,
              decoration: const InputDecoration(labelText: AppStrings.groundFormat, hintText: AppStrings.groundFormatHint),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _surface,
              maxLength: 40,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(labelText: AppStrings.groundSurface, hintText: AppStrings.groundSurfaceHint),
            ),
            const SizedBox(height: 8),
            Card(
              child: Column(
                children: [
                  SwitchListTile(
                    title: const Text(AppStrings.indoorLabel),
                    value: _indoor,
                    onChanged: (on) => setState(() => _indoor = on),
                  ),
                  const Divider(indent: 16, endIndent: 16),
                  SwitchListTile(
                    title: const Text(AppStrings.floodlightsLabel),
                    value: _floodlights,
                    onChanged: (on) => setState(() => _floodlights = on),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            TextFormField(
              controller: _price,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: AppStrings.pricePerHour, prefixText: '${PriceUtils.currency} '),
              validator: _priceError,
            ),
            const SizedBox(height: 8),
            Card(
              child: SwitchListTile(
                title: const Text(AppStrings.nightPriceLabel),
                subtitle: const Text(AppStrings.nightPriceHint),
                value: _nightPrice,
                onChanged: (on) => setState(() => _nightPrice = on),
              ),
            ),
            if (_nightPrice) ...[
              const SizedBox(height: 16),
              TextFormField(
                controller: _eveningPrice,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: AppStrings.eveningPrice, prefixText: '${PriceUtils.currency} '),
                validator: _priceError,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<int>(
                initialValue: _eveningFrom,
                icon: const Icon(Icons.keyboard_arrow_down_rounded),
                borderRadius: BorderRadius.circular(16),
                dropdownColor: Colors.white,
                menuMaxHeight: 400,
                decoration: const InputDecoration(labelText: AppStrings.eveningFrom),
                items: [
                  for (var h = 12; h <= 23; h++) DropdownMenuItem(value: h, child: Text(AppStrings.hourLabel(h))),
                ],
                onChanged: (h) => setState(() => _eveningFrom = h ?? 18),
              ),
            ],
            if (_venue case final venue? when _ground != null) ...[
              const SizedBox(height: 20),
              _Timings(venueId: venue.id, ground: _ground),
            ],
            const SizedBox(height: 20),
            const SectionHeader(AppStrings.bookings),
            const SizedBox(height: 8),
            Card(
              child: SwitchListTile(
                title: const Text(AppStrings.autoConfirm),
                subtitle: const Text(AppStrings.autoConfirmHint),
                value: _autoConfirm,
                onChanged: (value) => setState(() => _autoConfirm = value),
              ),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<int>(
              initialValue: _cancelOptions.contains(_freeCancelHours) ? _freeCancelHours : 24,
              isExpanded: true, // long choices shorten instead of running off the screen
              icon: const Icon(Icons.keyboard_arrow_down_rounded),
              borderRadius: BorderRadius.circular(16),
              dropdownColor: Colors.white,
              decoration: const InputDecoration(labelText: AppStrings.freeCancellation),
              items: [
                for (final hours in _cancelOptions)
                  DropdownMenuItem(value: hours, child: Text(AppStrings.freeCancelOption(hours))),
              ],
              onChanged: (hours) => setState(() => _freeCancelHours = hours ?? 24),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _policy,
              maxLength: 500,
              maxLines: 3,
              minLines: 1,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: AppStrings.cancellationRules,
                hintText: AppStrings.cancellationRulesHint,
              ),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _paymentInfo,
              maxLength: 300,
              maxLines: 3,
              minLines: 1,
              decoration: const InputDecoration(labelText: AppStrings.paymentInfo, hintText: AppStrings.paymentInfoHint),
            ),
            if (isNew) ...[
              const SizedBox(height: 20),
              const SectionHeader(AppStrings.groundManager),
              const SizedBox(height: 10),
              ManagerFields(name: _managerName, email: _managerEmail, phone: _managerPhone),
            ],
            if (_error != null) ...[
              const SizedBox(height: 12),
              FormError(_error!),
            ],
            const SizedBox(height: 24),
            PrimaryButton(
              label: isNew ? AppStrings.registerVenue : AppStrings.save,
              isLoading: _saving,
              onPressed: _save,
            ),
          ],
        ),
      ),
    );
  }
}

/// The ground's timings, and 'Set timings'. They save on their own screen,
/// not with this form.
class _Timings extends StatelessWidget {
  final String venueId;
  final Ground ground;

  const _Timings({required this.venueId, required this.ground});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionHeader(AppStrings.timings),
        const SizedBox(height: 10),
        if (ground.slots.isEmpty)
          const InfoNote(icon: Icons.schedule_rounded, text: AppStrings.noTimingsYet)
        else
          WeekTimings(ground: ground),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          icon: const Icon(Icons.schedule_rounded),
          label: const Text(AppStrings.setTimings),
          onPressed: () => context.push(Routes.venueTimingsFor(venueId)),
        ),
      ],
    );
  }
}

/// A photo to add: its preview once there is one, and what it's for.
class _PhotoCard extends StatelessWidget {
  final String title;
  final String hint;
  final IconData icon;
  final Widget? preview;
  final VoidCallback onTap;

  const _PhotoCard({
    required this.title,
    required this.hint,
    required this.icon,
    required this.preview,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        contentPadding: const EdgeInsets.all(12),
        leading: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: SizedBox.square(
            dimension: 56,
            child: preview ?? ColoredBox(color: AppColors.peach, child: Icon(icon, color: AppColors.primaryDeep)),
          ),
        ),
        title: Text(title),
        subtitle: Text(hint),
        onTap: onTap,
      ),
    );
  }
}
