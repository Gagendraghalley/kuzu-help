import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/strings/app_strings.dart';
import '../../core/utils/image_utils.dart';
import 'icon_tile.dart';

/// Asks 'Take a photo' or 'Choose from gallery', then returns the compressed
/// JPEG, or null if the user cancelled (B1, B3, D1).
Future<Uint8List?> pickPhoto(BuildContext context) async {
  final source = await showModalBottomSheet<ImageSource>(
    context: context,
    showDragHandle: true,
    builder: (context) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 0, 8, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const IconTile(icon: Icons.photo_camera_outlined),
              title: const Text(AppStrings.takePhoto),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            ListTile(
              leading: const IconTile(icon: Icons.photo_library_outlined),
              title: const Text(AppStrings.chooseFromGallery),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
          ],
        ),
      ),
    ),
  );
  if (source == null) return null;
  try {
    return await ImageUtils.pickAndCompress(source: source);
  } on PlatformException {
    // Usually camera or photo access was refused.
    if (context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text(AppStrings.photoAccessDenied)));
    }
    return null;
  }
}
