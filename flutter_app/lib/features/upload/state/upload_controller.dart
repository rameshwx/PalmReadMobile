import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_config.dart';
import '../../capture/state/capture_controller.dart';
import '../../result/data/palm_reads_api.dart';
import '../../result/domain/palm_read_models.dart';

class UploadState {
  const UploadState({
    this.status = 'idle',
    this.progress = 0,
    this.readId,
    this.error,
    this.lastDetail,
  });

  final String status;
  final double progress;
  final String? readId;
  final String? error;
  final PalmReadDetail? lastDetail;

  UploadState copyWith({
    String? status,
    double? progress,
    String? readId,
    String? error,
    PalmReadDetail? lastDetail,
  }) {
    return UploadState(
      status: status ?? this.status,
      progress: progress ?? this.progress,
      readId: readId ?? this.readId,
      error: error,
      lastDetail: lastDetail ?? this.lastDetail,
    );
  }
}

final uploadControllerProvider =
    StateNotifierProvider<UploadController, UploadState>((ref) {
  return UploadController(ref);
});

class UploadController extends StateNotifier<UploadState> {
  UploadController(this.ref) : super(const UploadState());

  final Ref ref;

  Future<void> startUpload() async {
    final capture = ref.read(captureControllerProvider);
    if (capture.imageFile == null) {
      state = state.copyWith(status: 'failed', error: 'No image selected');
      return;
    }

    state = state.copyWith(status: 'uploading', progress: 0, error: null);

    try {
      final api = ref.read(palmReadsApiProvider);
      final create = await api.createPalmRead(
        imageFile: capture.imageFile!,
        handednessHint: capture.handedness,
        onSendProgress: (sent, total) {
          final progress = total <= 0 ? 0.0 : (sent / total).clamp(0.0, 1.0);
          state = state.copyWith(progress: progress);
        },
      );

      state = state.copyWith(status: 'polling', readId: create.id, progress: 1);

      for (var i = 0; i < 60; i++) {
        final detail = await api.getPalmRead(create.id);
        state = state.copyWith(lastDetail: detail);

        if (detail.status == 'completed') {
          state = state.copyWith(status: 'completed');
          return;
        }
        if (detail.status == 'failed') {
          state = state.copyWith(
              status: 'failed', error: detail.failureReason ?? 'CV failed');
          return;
        }

        await Future<void>.delayed(
          const Duration(seconds: AppConfig.pollIntervalSeconds),
        );
      }

      state = state.copyWith(
          status: 'failed', error: 'Timed out while waiting for result');
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        state = state.copyWith(
          status: 'failed',
          error: 'Your session has expired. Redirecting to login...',
        );
        return;
      }

      state = state.copyWith(status: 'failed', error: e.toString());
    } catch (e) {
      state = state.copyWith(status: 'failed', error: e.toString());
    }
  }

  void reset() {
    state = const UploadState();
  }
}
