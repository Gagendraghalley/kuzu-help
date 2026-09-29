import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show PostgrestException;

import '../../../core/constants/app_constants.dart';
import '../../../core/strings/app_strings.dart';
import '../../../core/utils/error_messages.dart';
import '../../../core/utils/phone_utils.dart';
import '../../../core/utils/text_utils.dart';
import '../../../shared/models/profile.dart';
import '../../../shared/widgets/async_view.dart';
import '../../../shared/widgets/photo_picker.dart';
import '../../../shared/widgets/primary_button.dart';
import '../../customer/data/directory_repository.dart';
import '../../customer/providers/worker_details_providers.dart';
import '../../profile/providers/profile_providers.dart';
import '../data/job_repository.dart';
import '../providers/job_providers.dart';

/// Request a job (from C3)
/// Purpose: Tell a worker what's needed, where and when, without leaving the app.
/// Backend: Uploads the optional photo to job-photos; adds a job_requests row.
/// Done when: The worker is notified and sees it under Job requests.
class JobRequestScreen extends ConsumerWidget {
  final String workerId;

  const JobRequestScreen({super.key, required this.workerId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final details = ref.watch(workerDetailsProvider(workerId));
    final profile = ref.watch(myProfileProvider);

    return Scaffold(
      appBar: AppBar(title: const Text(AppStrings.requestJob)),
      body: SafeArea(
        child: AsyncView(
          value: details,
          onRetry: () => ref.invalidate(workerDetailsProvider(workerId)),
          data: (details) => details == null
              ? const Center(child: Text(AppStrings.workerNotListed))
              : _JobForm(details: details, profile: profile.valueOrNull),
        ),
      ),
    );
  }
}

class _JobForm extends ConsumerStatefulWidget {
  final WorkerDetails details;
  final Profile? profile; // fills in where and the phone number

  const _JobForm({required this.details, required this.profile});

  @override
  ConsumerState<_JobForm> createState() => _JobFormState();
}

class _JobFormState extends ConsumerState<_JobForm> {
  final _formKey = GlobalKey<FormState>();
  final _description = TextEditingController();
  final _when = TextEditingController();
  late final _address = TextEditingController(
    text: [widget.profile?.town, widget.profile?.dzongkhag]
        .where((part) => part != null && part.trim().isNotEmpty)
        .join(', '),
  );
  late final _phone = TextEditingController(
    text: widget.profile?.phone?.replaceFirst(AppConstants.countryCode, ''),
  );
  late String? _categoryId =
      widget.details.services.length == 1 ? widget.details.services.single.categoryId : null;
  Uint8List? _photo;
  bool _sending = false;
  String? _error;

  @override
  void dispose() {
    _description.dispose();
    _when.dispose();
    _address.dispose();
    _phone.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (_sending || !_formKey.currentState!.validate()) return;
    setState(() {
      _sending = true;
      _error = null;
    });
    final workerId = widget.details.worker.id;
    try {
      await ref.read(jobRepositoryProvider).sendRequest(
            workerId: workerId,
            categoryId: _categoryId,
            description: _description.text.trim(),
            whenNeeded: _when.text.orNull,
            address: _address.text.trim(),
            contactPhone: PhoneUtils.toInternational(_phone.text),
            photo: _photo,
          );
      ref.invalidate(myJobsProvider);
      ref.invalidate(hasContactedProvider(workerId)); // sending one counts as getting in touch
      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      context.pop();
      messenger.showSnackBar(const SnackBar(content: Text(AppStrings.jobRequestSent)));
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = switch (e) {
            // One open request per customer and worker.
            PostgrestException(code: '23505') => AppStrings.jobAlreadyOpen,
            // The worker stopped taking work (or is no longer listed).
            PostgrestException(code: '42501') => AppStrings.workerNotTakingWork,
            _ => ErrorMessages.from(e),
          });
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final services = widget.details.services;
    final photo = _photo;

    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text(AppStrings.jobRequestIntro(widget.details.worker.fullName),
              style: Theme.of(context).textTheme.bodyLarge),
          const SizedBox(height: 20),
          if (services.length > 1) ...[
            DropdownButtonFormField<String>(
              initialValue: _categoryId,
              decoration: const InputDecoration(labelText: AppStrings.jobService),
              items: [
                for (final service in services)
                  DropdownMenuItem(value: service.categoryId, child: Text(service.categoryName ?? '')),
              ],
              onChanged: (id) => setState(() => _categoryId = id),
            ),
            const SizedBox(height: 16),
          ],
          TextFormField(
            controller: _description,
            minLines: 3,
            maxLines: 6,
            maxLength: 1000,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: AppStrings.jobDescription,
              hintText: AppStrings.jobDescriptionHint,
              alignLabelWithHint: true,
            ),
            validator: (v) => v.orEmpty.isEmpty ? AppStrings.describeJob : null,
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: _address,
            maxLength: 200,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(labelText: AppStrings.jobAddress, hintText: AppStrings.jobAddressHint),
            validator: (v) => v.orEmpty.isEmpty ? AppStrings.enterAddress : null,
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: _when,
            maxLength: 100,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(labelText: AppStrings.jobWhen, hintText: AppStrings.jobWhenHint),
          ),
          const SizedBox(height: 8),
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
          const SizedBox(height: 16),
          Card(
            clipBehavior: Clip.antiAlias,
            child: ListTile(
              contentPadding: const EdgeInsets.all(12),
              leading: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: SizedBox.square(
                  dimension: 56,
                  child: photo == null
                      ? const Icon(Icons.add_a_photo_outlined)
                      : Image.memory(photo, fit: BoxFit.cover),
                ),
              ),
              title: const Text(AppStrings.jobPhoto),
              subtitle: Text(photo == null ? AppStrings.jobPhotoHint : AppStrings.photoReady),
              onTap: () async {
                final picked = await pickPhoto(context);
                if (picked != null) setState(() => _photo = picked);
              },
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Semantics(
              liveRegion: true,
              child: Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ),
          ],
          const SizedBox(height: 24),
          PrimaryButton(label: AppStrings.sendRequest, isLoading: _sending, onPressed: _send),
        ],
      ),
    );
  }
}

extension on String? {
  String get orEmpty => this?.trim() ?? '';
}
