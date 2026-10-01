import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';

/// Looks like a search box; the search itself is its own screen ([route]).
class SearchBoxButton extends StatelessWidget {
  final String hint;
  final String route;

  /// A thin border, for when the box sits on the page rather than a BrandPanel.
  final bool outlined;

  const SearchBoxButton({super.key, required this.hint, required this.route, this.outlined = false});

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16),
      side: outlined ? const BorderSide(color: AppColors.line) : BorderSide.none,
    );
    return Semantics(
      button: true,
      child: Material(
        color: Colors.white,
        shape: shape,
        child: InkWell(
          customBorder: shape,
          onTap: () => context.push(route),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            child: Row(
              children: [
                const Icon(Icons.search_rounded, color: AppColors.primaryDeep),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(hint, style: text.bodyLarge?.copyWith(color: AppColors.muted)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
