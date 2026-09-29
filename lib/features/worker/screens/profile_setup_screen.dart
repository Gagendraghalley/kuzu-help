import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/router/route_names.dart';
import '../../../core/strings/app_strings.dart';
import '../../../core/utils/error_messages.dart';
import '../../../core/utils/phone_utils.dart';
import '../../../core/utils/text_utils.dart';
import '../../../shared/models/profile.dart';
import '../../../shared/models/worker_profile.dart';
import '../../../shared/widgets/async_view.dart';
import '../../../shared/widgets/avatar_picker.dart';
import '../../../shared/widgets/confirm_dialog.dart';
import '../../../shared/widgets/dzongkhag_field.dart';
import '../../../shared/widgets/primary_button.dart';
import '../../auth/widgets/logout_button.dart';
import '../../customer/providers/worker_details_providers.dart';
import '../../profile/data/profile_repository.dart';
import '../../profile/providers/profile_providers.dart';
import '../data/worker_repository.dart';
import '../providers/worker_providers.dart';
import '../widgets/setup_progress.dart';

/// B1 Profile setup
/// Purpose: Collect the information customers will see.
/// Backend: Uploads to avatars; updates profiles; creates worker_profiles (status pending).
/// Done when: Data appears correctly in the Table Editor.
/// Also opened from B4, B5 and Settings to edit; then it goes back when saved.
/// During setup, 'I only want to find workers' switches the account to customer.
class ProfileSetupScreen extends ConsumerWidget {
  const ProfileSetupScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final form = ref.watch(workerProfileFormProvider);
    final editing = context.canPop();

    return Scaffold(
      appBar: AppBar(
        title: const Text(AppStrings.workerProfileTitle),
        actions: editing ? null : const [LogoutButton()],
      ),
      body: SafeArea(
        child: AsyncView(
          value: form,
          onRetry: () {
            ref.invalidate(myProfileProvider);
            ref.invalidate(myWorkerProfileProvider);
          },
          data: (data) => _ProfileForm(profile: data.$1, worker: data.$2, editing: editing),
        ),
      ),
    );
  }
}

class _ProfileForm extends ConsumerStatefulWidget {
  final Profile? profile;
  final WorkerProfile? worker;
  final bool editing;

  const _ProfileForm({required this.profile, required this.worker, required this.editing});

  @override
  ConsumerState<_ProfileForm> createState() => _ProfileFormState();
}

class _ProfileFormState extends ConsumerState<_ProfileForm> {
  final _formKey = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.profile?.fullName);
  late final _phone = TextEditingController(
    text: widget.worker?.whatsappNumber?.replaceFirst(AppConstants.countryCode, ''),
  );
  late final _town = TextEditingController(text: widget.profile?.town);
  late final _years = TextEditingController(text: widget.worker?.yearsExperience.toString());
  late final _bio = TextEditingController(text: widget.worker?.bio);
  late String? _dzongkhag = widget.profile?.dzongkhag;
  Uint8List? _photo;
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    for (final c in [_name, _phone, _town, _years, _bio]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving || !_formKey.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref.read(profileRepositoryProvider).updateProfile(
            fullName: _name.text.trim(),
            dzongkhag: _dzongkhag,
            town: _town.text.orNull,
            photo: _photo,
          );
      await ref.read(workerRepositoryProvider).saveWorkerDetails(
            whatsappNumber: PhoneUtils.toInternational(_phone.text),
            yearsExperience: int.parse(_years.text),
            bio: _bio.text.orNull,
          );
      ref.invalidate(myProfileProvider);
      ref.invalidate(myWorkerProfileProvider);
      ref.invalidate(workerDetailsProvider);
      if (!mounted) return;
      if (widget.editing) {
        final messenger = ScaffoldMessenger.of(context);
        context.pop();
        messenger.showSnackBar(const SnackBar(content: Text(AppStrings.saved)));
      } else {
        context.go(Routes.workerServices);
      }
    } catch (e) {
      if (mounted) setState(() => _error = ErrorMessages.from(e));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          if (!widget.editing) ...[
            const SetupProgress(step: 1),
            const SizedBox(height: 20),
          ],
          Text(AppStrings.workerProfileHint, style: text.bodyLarge),
          const SizedBox(height: 24),
          Center(
            child: AvatarPicker(
              currentUrl: widget.profile?.avatarUrl,
              picked: _photo,
              name: _name.text,
              onPicked: (photo) => setState(() => _photo = photo),
            ),
          ),
          Text(
            AppStrings.photoHint,
            textAlign: TextAlign.center,
            style: text.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 24),
          TextFormField(
            controller: _name,
            decoration: const InputDecoration(labelText: AppStrings.name),
            textCapitalization: TextCapitalization.words,
            textInputAction: TextInputAction.next,
            autofillHints: const [AutofillHints.name],
            validator: (v) => (v ?? '').trim().length < 2 ? AppStrings.enterName : null,
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _phone,
            decoration: const InputDecoration(
              labelText: AppStrings.mobileNumber,
              hintText: AppStrings.mobileHint,
              prefixText: '${AppConstants.countryCode} ',
              counterText: '',
            ),
            keyboardType: TextInputType.phone,
            textInputAction: TextInputAction.next,
            maxLength: 8,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            autofillHints: const [AutofillHints.telephoneNumberNational],
            validator: (v) => PhoneUtils.isValidMobile(v ?? '') ? null : AppStrings.invalidMobile,
          ),
          const SizedBox(height: 16),
          DzongkhagField(
            initialValue: _dzongkhag,
            required: true,
            onChanged: (d) => setState(() => _dzongkhag = d),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _town,
            decoration: const InputDecoration(labelText: AppStrings.town),
            textCapitalization: TextCapitalization.words,
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _years,
            decoration: const InputDecoration(labelText: AppStrings.yearsExperience, counterText: ''),
            keyboardType: TextInputType.number,
            textInputAction: TextInputAction.next,
            maxLength: 2,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            validator: (v) {
              final years = int.tryParse(v ?? '');
              return years == null || years > 60 ? AppStrings.invalidYears : null;
            },
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _bio,
            decoration: const InputDecoration(
              labelText: AppStrings.bio,
              hintText: AppStrings.bioHint,
              alignLabelWithHint: true,
            ),
            minLines: 3,
            maxLines: 6,
            maxLength: 500,
            textCapitalization: TextCapitalization.sentences,
          ),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Semantics(
              liveRegion: true,
              child: Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ),
          ],
          const SizedBox(height: 24),
          PrimaryButton(
            label: widget.editing ? AppStrings.save : AppStrings.saveAndContinue,
            isLoading: _saving,
            onPressed: _save,
          ),
          if (!widget.editing) ...[
            const SizedBox(height: 8),
            // For people who chose 'I offer a service' by mistake.
            TextButton(
              onPressed: _saving ? null : _onlyFindWorkers,
              child: const Text(AppStrings.onlyWantToFindWorkers),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _onlyFindWorkers() async {
    if (!await confirmStopOfferingServices(context)) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref.read(profileRepositoryProvider).becomeCustomer();
      ref.invalidate(myProfileProvider);
      // The splash (A1) sends customers to Customer Home (C1).
      if (mounted) context.go(Routes.splash);
    } catch (e) {
      if (mounted) setState(() => _error = ErrorMessages.from(e));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}
