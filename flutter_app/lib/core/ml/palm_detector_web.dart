import 'dart:typed_data';

import '../utils/image_quality.dart';

/// Browser-safe hand likelihood check.
///
/// The native Android detector remains the authoritative on-device detector on
/// Android. On the web we cannot use the Android method channel, so this
/// lightweight image-only check runs before upload and prevents obviously
/// invalid selections from reaching the server. The server still performs the
/// authoritative MediaPipe validation after receiving an upload.
class PalmDetector {
  static Future<bool?> detectHand(
    String imagePath, {
    Uint8List? imageBytes,
  }) async {
    if (imageBytes == null || imageBytes.isEmpty) {
      return null;
    }

    try {
      final quality = await ImageQuality.evaluateAsync(imageBytes);
      return quality.isLikelyHand;
    } catch (_) {
      // A failed local check is reported as unknown so a valid image is not
      // lost because a browser could not decode it.
      return null;
    }
  }
}
