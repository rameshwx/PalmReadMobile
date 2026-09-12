import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:palm_read_mobile/core/utils/image_quality.dart';

void main() {
  test('preserves color pixels for the browser hand-likelihood check', () {
    final image = img.Image(width: 64, height: 64);
    for (var y = 0; y < image.height; y++) {
      for (var x = 0; x < image.width; x++) {
        image.setPixelRgb(x, y, 150, 110, 95);
      }
    }

    final result = ImageQuality.evaluate(img.encodeJpg(image));

    expect(result.palmCoverage, greaterThan(0.5));
    expect(result.isLikelyHand, isTrue);
  });
}
