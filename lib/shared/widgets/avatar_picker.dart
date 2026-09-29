import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../core/strings/app_strings.dart';
import 'avatar_image.dart';
import 'photo_picker.dart';

/// Big round photo with a camera button (B1, D1). Shows [picked] once a new
/// photo is chosen, until then the saved one at [currentUrl].
class AvatarPicker extends StatelessWidget {
  final String? currentUrl;
  final Uint8List? picked;
  final String name;
  final ValueChanged<Uint8List> onPicked;

  const AvatarPicker({
    super.key,
    required this.currentUrl,
    required this.picked,
    required this.name,
    required this.onPicked,
  });

  static const _size = 120.0;

  Future<void> _pick(BuildContext context) async {
    final photo = await pickPhoto(context);
    if (photo != null) onPicked(photo);
  }

  @override
  Widget build(BuildContext context) {
    final picked = this.picked;
    final hasPhoto = picked != null || (currentUrl ?? '').isNotEmpty;
    final label = hasPhoto ? AppStrings.changePhoto : AppStrings.addPhoto;

    return Column(
      children: [
        Stack(
          children: [
            picked != null
                ? Container(
                    width: _size,
                    height: _size,
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white,
                      boxShadow: [
                        BoxShadow(color: Colors.black.withValues(alpha: 0.12), blurRadius: 12, offset: const Offset(0, 4)),
                      ],
                    ),
                    child: ClipOval(child: Image.memory(picked, fit: BoxFit.cover)),
                  )
                : AvatarImage(url: currentUrl, name: name, size: _size, ring: true),
            Positioned(
              right: 0,
              bottom: 0,
              child: DecoratedBox(
                decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.white),
                child: Padding(
                  padding: const EdgeInsets.all(3),
                  child: IconButton.filled(
                    icon: const Icon(Icons.photo_camera_rounded, size: 20),
                    tooltip: label,
                    onPressed: () => _pick(context),
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        TextButton(onPressed: () => _pick(context), child: Text(label)),
      ],
    );
  }
}
