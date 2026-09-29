import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/strings/app_strings.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/launcher_utils.dart';
import '../data/contact_repository.dart';
import '../providers/worker_details_providers.dart';

/// Big Call and WhatsApp buttons using LauncherUtils (C3). Each tap is
/// recorded: the worker is told someone is getting in touch, and the
/// customer can then review them.
class ContactButtons extends ConsumerWidget {
  final String workerId;
  final String phone;

  const ContactButtons({super.key, required this.workerId, required this.phone});

  /// Tells the user when the phone has no app for the link. Recording the
  /// contact never holds up or stops the call: if it fails, it just isn't recorded.
  Future<void> _open(
    BuildContext context,
    WidgetRef ref,
    String method,
    Future<bool> Function() launch,
    String failMessage,
  ) async {
    // The page may be gone when this finishes, so not through [ref].
    final container = ProviderScope.containerOf(context, listen: false);
    ref
        .read(contactRepositoryProvider)
        .recordContact(workerId, method)
        .then((_) => container.invalidate(hasContactedProvider(workerId)))
        .ignore();
    bool opened;
    try {
      opened = await launch();
    } catch (_) {
      opened = false;
    }
    if (!opened && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(failMessage)));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Row(
      children: [
        Expanded(
          child: FilledButton.icon(
            icon: const Icon(Icons.call_rounded),
            label: const Text(AppStrings.call),
            onPressed: () => _open(context, ref, ContactMethod.call, () => LauncherUtils.call(phone),
                AppStrings.cannotOpenPhone),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: FilledButton.icon(
            style: FilledButton.styleFrom(backgroundColor: AppColors.whatsapp),
            icon: const Icon(Icons.chat_rounded),
            label: const Text(AppStrings.whatsapp),
            onPressed: () => _open(context, ref, ContactMethod.whatsapp,
                () => LauncherUtils.whatsapp(phone), AppStrings.cannotOpenWhatsapp),
          ),
        ),
      ],
    );
  }
}
