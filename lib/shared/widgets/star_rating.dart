import 'package:flutter/material.dart';

import '../../core/strings/app_strings.dart';
import '../../core/theme/app_colors.dart';

/// Shows 1–5 stars; when onChanged is given it becomes a picker (C4).
class StarRating extends StatelessWidget {
  final double rating;
  final double size;
  final ValueChanged<int>? onChanged;

  const StarRating({super.key, required this.rating, this.size = 18, this.onChanged});

  @override
  Widget build(BuildContext context) {
    final onChanged = this.onChanged;
    final empty = Theme.of(context).colorScheme.outline;

    Icon star(int n) {
      final icon = rating >= n
          ? Icons.star_rounded
          : rating >= n - 0.5
              ? Icons.star_half_rounded
              : Icons.star_outline_rounded;
      return Icon(icon, size: size, color: rating >= n - 0.5 ? AppColors.saffron : empty);
    }

    if (onChanged == null) {
      return Semantics(
        label: AppStrings.ratedOutOf5(rating),
        excludeSemantics: true,
        child: Row(mainAxisSize: MainAxisSize.min, children: [for (var n = 1; n <= 5; n++) star(n)]),
      );
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var n = 1; n <= 5; n++)
          IconButton(
            icon: star(n),
            tooltip: AppStrings.starsLabel(n),
            onPressed: () => onChanged(n),
          ),
      ],
    );
  }
}
