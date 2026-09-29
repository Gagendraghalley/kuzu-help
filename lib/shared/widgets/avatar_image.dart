import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

/// Round photo using cached_network_image to save mobile data. Shows the
/// person's initials when there is no photo. The name is always shown next
/// to it, so screen readers skip it. [ring] draws a white edge around it, for
/// photos on coloured panels.
class AvatarImage extends StatelessWidget {
  final String? url;
  final String name;
  final double size;
  final bool ring;

  const AvatarImage({super.key, required this.url, required this.name, this.size = 56, this.ring = false});

  @override
  Widget build(BuildContext context) {
    final url = this.url;
    final initials = _Initials(name: name, size: size);
    final photo = ClipOval(
      child: url == null || url.isEmpty
          ? initials
          : CachedNetworkImage(
              imageUrl: url,
              fit: BoxFit.cover,
              placeholder: (_, __) => initials,
              errorWidget: (_, __, ___) => initials,
            ),
    );
    return ExcludeSemantics(
      child: SizedBox.square(
        dimension: size,
        child: ring
            ? DecoratedBox(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(color: Colors.black.withValues(alpha: 0.12), blurRadius: 12, offset: const Offset(0, 4)),
                  ],
                ),
                child: Padding(padding: EdgeInsets.all(size > 80 ? 4 : 3), child: photo),
              )
            : photo,
      ),
    );
  }
}

class _Initials extends StatelessWidget {
  final String name;
  final double size;

  const _Initials({required this.name, required this.size});

  @override
  Widget build(BuildContext context) {
    final letters = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((word) => word.isNotEmpty)
        .take(2)
        .map((word) => word[0].toUpperCase())
        .join();
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFFF3E7), Color(0xFFFBD9BA)],
        ),
      ),
      alignment: Alignment.center,
      child: letters.isEmpty
          ? Icon(Icons.person_rounded, size: size * 0.5, color: AppColors.primaryDeep)
          : Text(
              letters,
              style: TextStyle(
                fontSize: size * 0.36,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
                color: AppColors.primaryDeep,
              ),
            ),
    );
  }
}
