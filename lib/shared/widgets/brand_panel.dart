import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

/// Orange-to-maroon panel (AppColors.brandGradient) at the top of the home
/// screens, with two soft circles of light for depth. Text on it is white.
class BrandPanel extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;

  const BrandPanel({super.key, required this.child, this.padding = const EdgeInsets.all(20)});

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(24);
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: AppColors.brandGradient,
        borderRadius: radius,
        boxShadow: [
          BoxShadow(
            color: AppColors.maroon.withValues(alpha: 0.22),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: radius,
        child: Stack(
          children: [
            Positioned(right: -48, top: -64, child: _Glow(size: 180, color: AppColors.saffron, alpha: 0.18)),
            Positioned(left: -40, bottom: -90, child: _Glow(size: 160, color: Colors.white, alpha: 0.06)),
            Padding(padding: padding, child: child),
          ],
        ),
      ),
    );
  }
}

class _Glow extends StatelessWidget {
  final double size;
  final Color color;
  final double alpha;

  const _Glow({required this.size, required this.color, required this.alpha});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(shape: BoxShape.circle, color: color.withValues(alpha: alpha)),
    );
  }
}
