import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class PalmDetector {
  static const MethodChannel _channel = MethodChannel('palm_detector');

  static Future<bool?> detectHand(String imagePath) async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      return null;
    }

    try {
      return await _channel
          .invokeMethod<bool>('detectHand', {'imagePath': imagePath});
    } on PlatformException {
      return null;
    } on MissingPluginException {
      return null;
    }
  }
}
