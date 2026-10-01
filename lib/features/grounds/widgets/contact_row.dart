import 'package:flutter/material.dart';

import '../../../core/strings/app_strings.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/launcher_utils.dart';

/// Call or WhatsApp someone who booked, side by side.
class ContactRow extends StatelessWidget {
  final String phone; // +975XXXXXXXX

  const ContactRow({super.key, required this.phone});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: FilledButton.icon(
            icon: const Icon(Icons.call),
            label: const Text(AppStrings.call),
            onPressed: () => LauncherUtils.call(phone),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: FilledButton.icon(
            style: FilledButton.styleFrom(backgroundColor: AppColors.whatsapp),
            icon: const Icon(Icons.chat),
            label: const Text(AppStrings.whatsapp),
            onPressed: () => LauncherUtils.whatsapp(phone),
          ),
        ),
      ],
    );
  }
}
