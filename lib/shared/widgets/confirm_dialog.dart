import 'package:flutter/material.dart';

import '../../core/strings/app_strings.dart';

/// Asks before doing something big (log out, delete account, become a
/// worker). True only when the user taps [confirmLabel].
Future<bool> confirm(
  BuildContext context, {
  required String title,
  String? message,
  required String confirmLabel,
  bool destructive = false,
}) async {
  final colors = Theme.of(context).colorScheme;
  final result = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: message == null ? null : Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text(AppStrings.cancel),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          style: FilledButton.styleFrom(
            minimumSize: const Size(0, 44),
            backgroundColor: destructive ? colors.error : null,
          ),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  return result ?? false;
}

/// Worker -> customer, from Settings (D1) or profile setup (B1).
Future<bool> confirmStopOfferingServices(BuildContext context) => confirm(
      context,
      title: AppStrings.stopOfferingServices,
      message: AppStrings.stopOfferingServicesMessage,
      confirmLabel: AppStrings.continueLabel,
    );
