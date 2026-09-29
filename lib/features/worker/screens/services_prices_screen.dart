import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/route_names.dart';
import '../../../core/strings/app_strings.dart';
import '../../../core/utils/error_messages.dart';
import '../../../core/utils/text_utils.dart';
import '../../../shared/models/service_category.dart';
import '../../../shared/models/worker_service.dart';
import '../../../shared/widgets/async_view.dart';
import '../../../shared/widgets/form_error.dart';
import '../../../shared/widgets/primary_button.dart';
import '../../customer/providers/search_providers.dart';
import '../../customer/providers/worker_details_providers.dart';
import '../data/worker_repository.dart';
import '../providers/worker_providers.dart';
import '../widgets/service_price_tile.dart';
import '../widgets/setup_progress.dart';

/// B2 Services and prices
/// Purpose: Let workers choose what they offer.
/// Backend: Reads service_categories; saves rows in worker_services.
/// Done when: Adding and removing services updates rows correctly.
/// Also opened from B4, B5 and Settings to edit; then it goes back when saved.
class ServicesPricesScreen extends ConsumerWidget {
  const ServicesPricesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final form = ref.watch(servicesFormProvider);
    final editing = context.canPop();

    return Scaffold(
      appBar: AppBar(
        title: const Text(AppStrings.servicesTitle),
        // During setup, 'back' is the previous step.
        leading: editing ? null : BackButton(onPressed: () => context.go(Routes.workerSetup)),
      ),
      body: SafeArea(
        child: AsyncView(
          value: form,
          onRetry: () {
            ref.invalidate(categoriesProvider);
            ref.invalidate(myServicesProvider);
          },
          data: (data) => _ServicesForm(categories: data.$1, current: data.$2, editing: editing),
        ),
      ),
    );
  }
}

class _ServicesForm extends ConsumerStatefulWidget {
  final List<ServiceCategory> categories;
  final List<WorkerService> current;
  final bool editing;

  const _ServicesForm({required this.categories, required this.current, required this.editing});

  @override
  ConsumerState<_ServicesForm> createState() => _ServicesFormState();
}

class _ServicesFormState extends ConsumerState<_ServicesForm> {
  late final Set<String> _selected = {for (final s in widget.current) s.categoryId};
  late final Map<String, TextEditingController> _priceNotes = {
    for (final category in widget.categories)
      category.id: TextEditingController(
        text: widget.current.where((s) => s.categoryId == category.id).firstOrNull?.priceNote,
      ),
  };
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    for (final c in _priceNotes.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) return;
    if (_selected.isEmpty) {
      setState(() => _error = AppStrings.chooseOneService);
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref
          .read(workerRepositoryProvider)
          .saveServices({for (final id in _selected) id: _priceNotes[id]!.text.orNull});
      ref.invalidate(myServicesProvider);
      ref.invalidate(workerDetailsProvider);
      if (!mounted) return;
      if (widget.editing) {
        final messenger = ScaffoldMessenger.of(context);
        context.pop();
        messenger.showSnackBar(const SnackBar(content: Text(AppStrings.saved)));
      } else {
        context.go(Routes.workerVerification);
      }
    } catch (e) {
      if (mounted) setState(() => _error = ErrorMessages.from(e));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        if (!widget.editing) ...[
          const SetupProgress(step: 2),
          const SizedBox(height: 20),
        ],
        Text(AppStrings.servicesHint, style: Theme.of(context).textTheme.bodyLarge),
        const SizedBox(height: 20),
        for (final category in widget.categories) ...[
          ServicePriceTile(
            category: category,
            selected: _selected.contains(category.id),
            priceNote: _priceNotes[category.id]!,
            onSelected: (selected) => setState(() {
              selected ? _selected.add(category.id) : _selected.remove(category.id);
              _error = null;
            }),
          ),
          const SizedBox(height: 12),
        ],
        if (_error != null) ...[
          FormError(_error!),
          const SizedBox(height: 8),
        ],
        const SizedBox(height: 12),
        PrimaryButton(
          label: widget.editing ? AppStrings.save : AppStrings.saveAndContinue,
          isLoading: _saving,
          onPressed: _save,
        ),
      ],
    );
  }
}
