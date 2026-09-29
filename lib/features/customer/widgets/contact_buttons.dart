import 'package:flutter/material.dart';

import '../../../core/strings/app_strings.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/launcher_utils.dart';

/// Big Call and WhatsApp buttons using LauncherUtils (C3).
class ContactButtons extends StatelessWidget {
  final String phone;

  const ContactButtons({super.key, required this.phone});

  /// Tells the user when the phone has no app for the link.
  static Future<void> _open(
    BuildContext context,
    Future<bool> Function() launch,
    String failMessage,
  ) async {
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
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: FilledButton.icon(
            icon: const Icon(Icons.call),
            label: const Text(AppStrings.call),
            onPressed: () =>
                _open(context, () => LauncherUtils.call(phone), AppStrings.cannotOpenPhone),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: FilledButton.icon(
            style: FilledButton.styleFrom(backgroundColor: AppColors.whatsapp),
            icon: const Icon(Icons.chat),
            label: const Text(AppStrings.whatsapp),
            onPressed: () =>
                _open(context, () => LauncherUtils.whatsapp(phone), AppStrings.cannotOpenWhatsapp),
          ),
        ),
      ],
    );
  }
}
