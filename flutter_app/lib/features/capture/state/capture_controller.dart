import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/utils/image_quality.dart';
import '../../../core/ml/palm_detector.dart';
import '../domain/capture_quality_result.dart';

class CaptureState {
  const CaptureState({
    this.imageBytes,
    this.imageFilename,
    this.quality,
    this.handDetected,
    this.handedness = 'right',
    this.isEvaluating = false,
  });

  final Uint8List? imageBytes;
  final String? imageFilename;
  final CaptureQualityResult? quality;
  final bool? handDetected;
  final String handedness;
  final bool isEvaluating;

  CaptureState copyWith({
    Uint8List? imageBytes,
    String? imageFilename,
    CaptureQualityResult? quality,
    bool? handDetected,
    String? handedness,
    bool? isEvaluating,
    bool clearImage = false,
  }) {
    return CaptureState(
      imageBytes: clearImage ? null : (imageBytes ?? this.imageBytes),
      imageFilename: clearImage ? null : (imageFilename ?? this.imageFilename),
      quality: clearImage ? null : (quality ?? this.quality),
      handDetected: clearImage ? null : (handDetected ?? this.handDetected),
      handedness: handedness ?? this.handedness,
      isEvaluating: isEvaluating ?? this.isEvaluating,
    );
  }
}

final captureControllerProvider =
    StateNotifierProvider<CaptureController, CaptureState>(
  (ref) => CaptureController(),
);

class CaptureController extends StateNotifier<CaptureState> {
  CaptureController() : super(const CaptureState());

  Future<void> setImage(XFile file) async {
    final handedness = state.handedness;
    final bytes = await file.readAsBytes();
    final filename = _filenameFor(file);

    // Set the image immediately so Verify Photo can render it while we run checks.
    state = CaptureState(
      imageBytes: bytes,
      imageFilename: filename,
      quality: null,
      handDetected: null,
      isEvaluating: true,
      handedness: handedness,
    );
    try {
      final handFuture = PalmDetector.detectHand(
        file.path,
        imageBytes: bytes,
      );
      final quality = await ImageQuality.evaluateAsync(bytes);
      final handDetected =
          await handFuture ?? (kIsWeb ? quality.isLikelyHand : null);

      state = CaptureState(
        imageBytes: bytes,
        imageFilename: filename,
        quality: quality,
        handDetected: handDetected,
        handedness: handedness,
        isEvaluating: false,
      );
    } catch (_) {
      state = CaptureState(
        imageBytes: bytes,
        imageFilename: filename,
        isEvaluating: false,
        handDetected: kIsWeb ? false : null,
        handedness: handedness,
      );
    }
  }

  String _filenameFor(XFile file) {
    final name = file.name.trim();
    return name.isEmpty ? 'palm.jpg' : name;
  }

  void setHandedness(String handedness) {
    state = state.copyWith(handedness: handedness);
  }

  void clear() {
    state = state.copyWith(
      clearImage: true,
      handedness: 'right',
      isEvaluating: false,
    );
  }
}
