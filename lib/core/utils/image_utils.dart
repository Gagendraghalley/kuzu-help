import 'dart:typed_data';

import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image_picker/image_picker.dart';

/// Pick a photo (camera or gallery) and compress it to roughly 100–200 KB.
class ImageUtils {
  static final _picker = ImagePicker();

  static Future<Uint8List?> pickAndCompress({required ImageSource source}) async {
    final file = await _picker.pickImage(source: source, maxWidth: 1280);
    if (file == null) return null;
    return FlutterImageCompress.compressWithFile(file.path, quality: 70, minWidth: 800);
  }
}
