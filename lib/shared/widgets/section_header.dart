import 'package:flutter/material.dart';

/// Bold section title with an optional button on the right.
class SectionHeader extends StatelessWidget {
  final String title;
  final Widget? action;

  const SectionHeader(this.title, {super.key, this.action});

  @override
  Widget build(BuildContext context) {
    final action = this.action;
    return Row(
      children: [
        Expanded(
          child: Semantics(
            header: true,
            child: Text(
              title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.3,
                  ),
            ),
          ),
        ),
        if (action != null) action,
      ],
    );
  }
}
