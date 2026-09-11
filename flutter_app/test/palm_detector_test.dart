import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:palm_read_mobile/core/ml/palm_detector.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('returns no local result on unsupported platforms', () async {
    final previousPlatform = debugDefaultTargetPlatformOverride;
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    late bool? detected;
    try {
      detected = await PalmDetector.detectHand('blob:test-image');
    } finally {
      debugDefaultTargetPlatformOverride = previousPlatform;
    }

    expect(detected, isNull);
  });
}
