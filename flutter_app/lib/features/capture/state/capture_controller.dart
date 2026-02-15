import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/utils/image_quality.dart';
import '../../../core/ml/palm_detector.dart';
import '../domain/capture_quality_result.dart';

class CaptureState {
  const CaptureState({
    this.imageFile,
    this.quality,
    this.handDetected,
    this.handedness = 'right',
    this.isEvaluating = false,
  });

  final File? imageFile;
  final CaptureQualityResult? quality;
  final bool? handDetected;
  final String handedness;
  final bool isEvaluating;

  CaptureState copyWith({
    File? imageFile,
    CaptureQualityResult? quality,
    bool? handDetected,
    String? handedness,
    bool? isEvaluating,
    bool clearImage = false,
  }) {
    return CaptureState(
      imageFile: clearImage ? null : (imageFile ?? this.imageFile),
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
    // Set the image immediately so Verify Photo can render it while we run checks.
    state = CaptureState(
      imageFile: File(file.path),
      quality: null,
      handDetected: null,
      isEvaluating: true,
      handedness: handedness,
    );
    try {
      final bytesFuture = file.readAsBytes();
      final handFuture = PalmDetector.detectHand(file.path);

      final bytes = await bytesFuture;
      final quality = await ImageQuality.evaluateAsync(bytes);
      final handDetected = await handFuture;

      state = CaptureState(
        imageFile: File(file.path),
        quality: quality,
        handDetected: handDetected,
        handedness: handedness,
        isEvaluating: false,
      );
    } catch (_) {
      state = CaptureState(
        imageFile: File(file.path),
        isEvaluating: false,
        handedness: handedness,
      );
    }
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
