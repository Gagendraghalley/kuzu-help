import 'package:flutter/material.dart';

import '../../core/strings/app_strings.dart';
import '../../core/theme/app_colors.dart';

/// A photo from a link, cropped to fill its box; a broken-image icon when it
/// can't load. Tap to see it full size (when [expandable]).
class PhotoThumb extends StatelessWidget {
  final String url;
  final double size;
  final bool expandable;

  const PhotoThumb({super.key, required this.url, this.size = 96, this.expandable = true});

  @override
  Widget build(BuildContext context) {
    final image = ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: SizedBox.square(
        dimension: size,
        child: Image.network(url, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const _Broken()),
      ),
    );
    if (!expandable) return image;
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => showPhoto(context, url),
      child: image,
    );
  }
}

/// Full screen, with pinch to zoom.
Future<void> showPhoto(BuildContext context, String url) => showDialog<void>(
      context: context,
      builder: (context) => Dialog.fullscreen(
        backgroundColor: Colors.black,
        child: Stack(
          children: [
            Positioned.fill(
              child: InteractiveViewer(
                child: Image.network(url, errorBuilder: (_, __, ___) => const _Broken()),
              ),
            ),
            SafeArea(
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white),
                tooltip: AppStrings.close,
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ],
        ),
      ),
    );

class _Broken extends StatelessWidget {
  const _Broken();

  @override
  Widget build(BuildContext context) =>
      const ColoredBox(color: AppColors.sand, child: Center(child: Icon(Icons.broken_image_outlined, color: AppColors.muted)));
}
