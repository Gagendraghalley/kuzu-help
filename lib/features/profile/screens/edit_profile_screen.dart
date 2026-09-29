import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/strings/app_strings.dart';
import '../../../core/utils/error_messages.dart';
import '../../../core/utils/text_utils.dart';
import '../../../shared/models/profile.dart';
import '../../../shared/widgets/async_view.dart';
import '../../../shared/widgets/avatar_picker.dart';
import '../../../shared/widgets/dzongkhag_field.dart';
import '../../../shared/widgets/form_error.dart';
import '../../../shared/widgets/primary_button.dart';
import '../data/profile_repository.dart';
import '../providers/profile_providers.dart';

/// D1 Edit profile
/// Purpose: Edit name, photo and location.
/// Backend: Updates the profiles row; uploads a new avatar.
/// Done when: Changes show everywhere after saving.
/// Workers edit these on B1 instead, together with what customers see.
class EditProfileScreen extends ConsumerWidget {
  const EditProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(myProfileProvider);

    return Scaffold(
      appBar: AppBar(title: const Text(AppStrings.editProfile)),
      body: SafeArea(
        child: AsyncView(
          value: profile,
          onRetry: () => ref.invalidate(myProfileProvider),
          data: (profile) => profile == null
              ? const SizedBox.shrink()
              : _EditProfileForm(profile: profile),
        ),
      ),
    );
  }
}

class _EditProfileForm extends ConsumerStatefulWidget {
  final Profile profile;

  const _EditProfileForm({required this.profile});

  @override
  ConsumerState<_EditProfileForm> createState() => _EditProfileFormState();
}

class _EditProfileFormState extends ConsumerState<_EditProfileForm> {
  final _formKey = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.profile.fullName);
  late final _town = TextEditingController(text: widget.profile.town);
  late String? _dzongkhag = widget.profile.dzongkhag;
  Uint8List? _photo;
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _town.dispose();
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
      ref.invalidate(myProfileProvider);
      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      context.pop();
      messenger.showSnackBar(const SnackBar(content: Text(AppStrings.profileSaved)));
    } catch (e) {
      if (mounted) setState(() => _error = ErrorMessages.from(e));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Center(
            child: AvatarPicker(
              currentUrl: widget.profile.avatarUrl,
              picked: _photo,
              name: widget.profile.fullName,
              onPicked: (photo) => setState(() => _photo = photo),
            ),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _name,
            decoration: const InputDecoration(labelText: AppStrings.name),
            textCapitalization: TextCapitalization.words,
            textInputAction: TextInputAction.next,
            autofillHints: const [AutofillHints.name],
            validator: (v) => (v ?? '').trim().length < 2 ? AppStrings.enterName : null,
          ),
          const SizedBox(height: 16),
          DzongkhagField(
            initialValue: _dzongkhag,
            onChanged: (d) => setState(() => _dzongkhag = d),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _town,
            decoration: const InputDecoration(labelText: AppStrings.town),
            textCapitalization: TextCapitalization.words,
          ),
          const SizedBox(height: 16),
          TextFormField(
            initialValue: widget.profile.email,
            enabled: false,
            decoration: const InputDecoration(
              labelText: AppStrings.email,
              helperText: AppStrings.emailCantChange,
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 16),
            FormError(_error!),
          ],
          const SizedBox(height: 24),
          PrimaryButton(label: AppStrings.save, isLoading: _saving, onPressed: _save),
        ],
      ),
    );
  }
}
