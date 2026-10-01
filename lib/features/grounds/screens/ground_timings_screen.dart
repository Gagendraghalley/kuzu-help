import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/strings/app_strings.dart';
import '../../../core/utils/error_messages.dart';
import '../../../shared/models/ground.dart';
import '../../../shared/widgets/async_view.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/form_error.dart';
import '../../../shared/widgets/info_note.dart';
import '../../../shared/widgets/primary_button.dart';
import '../data/venue_repository.dart';
import '../providers/venue_providers.dart';
import '../widgets/time_slots_editor.dart';

/// A ground's timings (its ground manager, and admins)
/// Purpose: The times people can book on each day, Monday to Sunday, as many
/// a day as the manager likes. Set once; changed here whenever needed.
/// Backend: set_ground_time_slots replaces the ground's time slots.
/// Done when: The ground's page shows the new times, and customers book them.
class GroundTimingsScreen extends ConsumerWidget {
  final String venueId;

  const GroundTimingsScreen({super.key, required this.venueId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text(AppStrings.setTimings)),
      body: SafeArea(
        child: AsyncView(
          value: ref.watch(venueDetailsProvider(venueId)),
          onRetry: () => ref.invalidate(venueDetailsProvider(venueId)),
          data: (details) {
            final ground = details?.grounds.firstOrNull;
            if (ground == null) {
              return const EmptyState(icon: Icons.schedule_rounded, message: AppStrings.typeAndPriceFirst);
            }
            return _TimingsForm(venueId: venueId, ground: ground);
          },
        ),
      ),
    );
  }
}

class _TimingsForm extends ConsumerStatefulWidget {
  final String venueId;
  final Ground ground;

  const _TimingsForm({required this.venueId, required this.ground});

  @override
  ConsumerState<_TimingsForm> createState() => _TimingsFormState();
}

class _TimingsFormState extends ConsumerState<_TimingsForm> {
  // By weekday (0 = Sunday); empty: closed that day.
  late final Map<int, List<TimeSlot>> _slots = {
    for (var day = 0; day < 7; day++) day: widget.ground.slotsOnWeekday(day),
  };
  bool _saving = false;
  String? _error;

  /// Monday's times (or closed) for the whole week, to change a day or two after.
  void _copyMonday() => setState(() {
        final monday = _slots[1] ?? const [];
        for (var day = 0; day < 7; day++) {
          _slots[day] = [for (final slot in monday) slot.on(day)];
        }
        _error = null;
      });

  Future<void> _save() async {
    if (_saving) return;
    final slots = [for (final day in _slots.values) ...day];
    if (slots.isEmpty) {
      setState(() => _error = AppStrings.addAtLeastOneTime);
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref.read(venueRepositoryProvider).saveTimeSlots(widget.ground.id, slots);
      ref.invalidate(venueDetailsProvider(widget.venueId));
      ref.invalidate(venuesProvider);
      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      context.pop();
      messenger.showSnackBar(const SnackBar(content: Text(AppStrings.timingsSaved)));
    } catch (e) {
      if (mounted) setState(() => _error = ErrorMessages.from(e));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const InfoNote(icon: Icons.schedule_rounded, text: AppStrings.timingsHint),
          const SizedBox(height: 16),
          TimeSlotsEditor(
            slots: _slots,
            onChanged: (day, slots) => setState(() {
              _slots[day] = slots;
              _error = null;
            }),
          ),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: TextButton.icon(
              icon: const Icon(Icons.copy_all_rounded),
              label: const Text(AppStrings.copyMondayToAll),
              onPressed: _copyMonday,
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            FormError(_error!),
          ],
          const SizedBox(height: 20),
          PrimaryButton(label: AppStrings.saveTimings, isLoading: _saving, onPressed: _save),
        ],
      ),
    );
  }
}
