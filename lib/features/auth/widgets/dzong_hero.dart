import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';

/// The brand's roof over the Welcome, log in and sign-up screens (A2–A5):
/// the logo's orange-to-maroon gradient under a faint lattice of the diamonds
/// beneath the logo, and a bottom edge that sweeps up at both ends like a
/// dzong's eaves, with a gold trim. [child] sits on it; its text is white.
class DzongHero extends StatelessWidget {
  final Widget child;

  const DzongHero({super.key, required this.child});

  /// How much higher the eaves are than the middle of the bottom edge.
  static const eaveLift = 44.0;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: const _DzongPainter(),
      child: Padding(padding: const EdgeInsets.only(bottom: eaveLift + 24), child: child),
    );
  }
}

class _DzongPainter extends CustomPainter {
  const _DzongPainter();

  /// The bottom edge, from the right eave to the left one, [raise] higher.
  static Path _eaves(Size size, {double raise = 0}) {
    final w = size.width;
    final h = size.height - raise;
    const lift = DzongHero.eaveLift;
    return Path()
      ..moveTo(w, h - lift)
      ..cubicTo(w * 0.86, h - lift * 0.25, w * 0.68, h, w / 2, h)
      ..cubicTo(w * 0.32, h, w * 0.14, h - lift * 0.25, 0, h - lift);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final bounds = Offset.zero & size;
    final roof = Path()
      ..moveTo(0, 0)
      ..lineTo(w, 0)
      ..extendWithPath(_eaves(size), Offset.zero) // down the right side, along the eaves
      ..close();

    canvas.save();
    canvas.clipPath(roof);
    canvas.drawRect(bounds, Paint()..shader = AppColors.brandGradient.createShader(bounds));

    // Warm light on the top corner.
    final glow = Rect.fromCircle(center: Offset(w * 0.92, 0), radius: w * 0.65);
    canvas.drawRect(
      glow,
      Paint()
        ..shader = RadialGradient(
          colors: [AppColors.saffron.withValues(alpha: 0.26), AppColors.saffron.withValues(alpha: 0)],
        ).createShader(glow),
    );

    // The diamonds, in staggered rows that fade out towards the eaves.
    const gap = 28.0;
    const r = 3.5;
    for (var row = 0; row * gap / 2 <= h; row++) {
      final y = row * gap / 2;
      final diamonds = Path();
      for (var x = row.isOdd ? gap / 2 : 0.0; x <= w + r; x += gap) {
        diamonds
          ..moveTo(x, y - r)
          ..lineTo(x + r, y)
          ..lineTo(x, y + r)
          ..lineTo(x - r, y)
          ..close();
      }
      canvas.drawPath(diamonds, Paint()..color = Colors.white.withValues(alpha: 0.09 * (1 - y / h)));
    }
    canvas.restore();

    // Gold trim just inside the eaves.
    canvas.drawPath(
      _eaves(size, raise: 7),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round
        ..color = AppColors.saffron.withValues(alpha: 0.9),
    );
  }

  @override
  bool shouldRepaint(_DzongPainter oldDelegate) => false;
}
