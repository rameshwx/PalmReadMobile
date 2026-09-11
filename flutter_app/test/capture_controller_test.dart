import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:palm_read_mobile/features/capture/state/capture_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('keeps selected XFile bytes and filename for cross-platform previews',
      () async {
    final controller = CaptureController();
    addTearDown(controller.dispose);

    final bytes = Uint8List.fromList([1, 2, 3, 4]);
    await controller.setImage(
      XFile.fromData(
        bytes,
        name: 'selected-palm.jpg',
        path: '/tmp/selected-palm.jpg',
        mimeType: 'image/jpeg',
      ),
    );

    expect(controller.state.imageBytes, orderedEquals(bytes));
    expect(controller.state.imageFilename, 'selected-palm.jpg');
    expect(controller.state.isEvaluating, isFalse);
  });

  test('clearing a capture removes its byte-backed image', () async {
    final controller = CaptureController();
    addTearDown(controller.dispose);

    await controller.setImage(XFile.fromData(
      Uint8List.fromList([5, 6, 7]),
      name: 'palm.png',
    ));
    controller.clear();

    expect(controller.state.imageBytes, isNull);
    expect(controller.state.imageFilename, isNull);
  });
}
