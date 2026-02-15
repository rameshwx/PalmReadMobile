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
    state = state.copyWith(isEvaluating: true);
    try {
      final bytes = await file.readAsBytes();
      final quality = await ImageQuality.evaluateAsync(bytes);
      final handDetected =
          await PalmDetector.detectHand(file.path) ?? true; // fallback: allow
      state = state.copyWith(
        imageFile: File(file.path),
        quality: quality,
        handDetected: handDetected,
        isEvaluating: false,
      );
    } catch (_) {
      state = state.copyWith(isEvaluating: false);
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
