import 'package:flutter/material.dart';

import '../../core/strings/app_strings.dart';

/// A bottom sheet's title with a close button beside it: the way back when
/// the sheet fills the screen.
class SheetTitle extends StatelessWidget {
  final String title;

  const SheetTitle(this.title, {super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(title, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
          ),
        ),
        IconButton(
          tooltip: AppStrings.close,
          icon: const Icon(Icons.close_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ],
    );
  }
}
