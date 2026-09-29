import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

/// Round photo using cached_network_image to save mobile data. Shows the
/// person's initials when there is no photo. The name is always shown next
/// to it, so screen readers skip it.
class AvatarImage extends StatelessWidget {
  final String? url;
  final String name;
  final double size;

  const AvatarImage({super.key, required this.url, required this.name, this.size = 56});

  @override
  Widget build(BuildContext context) {
    final url = this.url;
    final initials = _Initials(name: name, size: size);
    return ExcludeSemantics(
      child: SizedBox.square(
        dimension: size,
        child: ClipOval(
          child: url == null || url.isEmpty
              ? initials
              : CachedNetworkImage(
                  imageUrl: url,
                  fit: BoxFit.cover,
                  placeholder: (_, __) => initials,
                  errorWidget: (_, __, ___) => initials,
                ),
        ),
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
      color: AppColors.ivory,
      alignment: Alignment.center,
      child: letters.isEmpty
          ? Icon(Icons.person, size: size * 0.5, color: AppColors.primaryDeep)
          : Text(
              letters,
              style: TextStyle(
                fontSize: size * 0.36,
                fontWeight: FontWeight.bold,
                color: AppColors.primaryDeep,
              ),
            ),
    );
  }
}
