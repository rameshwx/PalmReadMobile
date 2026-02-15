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
    this.correlationId,
    this.pollAttempt = 0,
    this.maxAttempts = 60,
    this.error,
    this.lastDetail,
  });

  final String status;
  final double progress;
  final String? readId;
  final String? correlationId;
  final int pollAttempt;
  final int maxAttempts;
  final String? error;
  final PalmReadDetail? lastDetail;

  UploadState copyWith({
    String? status,
    double? progress,
    String? readId,
    String? correlationId,
    int? pollAttempt,
    int? maxAttempts,
    String? error,
    PalmReadDetail? lastDetail,
  }) {
    return UploadState(
      status: status ?? this.status,
      progress: progress ?? this.progress,
      readId: readId ?? this.readId,
      correlationId: correlationId ?? this.correlationId,
      pollAttempt: pollAttempt ?? this.pollAttempt,
      maxAttempts: maxAttempts ?? this.maxAttempts,
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
  CancelToken? _cancelToken;
  bool _cancelled = false;

  Future<void> startUpload() async {
    final capture = ref.read(captureControllerProvider);
    if (capture.imageFile == null) {
      state = state.copyWith(status: 'failed', error: 'No image selected');
      return;
    }

    _cancelled = false;
    _cancelToken?.cancel('restart');
    _cancelToken = CancelToken();

    state = state.copyWith(
      status: 'uploading',
      progress: 0,
      pollAttempt: 0,
      maxAttempts: 60,
      error: null,
    );

    try {
      final api = ref.read(palmReadsApiProvider);
      final create = await api.createPalmRead(
        imageFile: capture.imageFile!,
        handednessHint: capture.handedness,
        cancelToken: _cancelToken,
        onSendProgress: (sent, total) {
          final progress = total <= 0 ? 0.0 : (sent / total).clamp(0.0, 1.0);
          state = state.copyWith(progress: progress);
        },
      );

      state = state.copyWith(
        status: 'polling',
        readId: create.id,
        correlationId: create.correlationId,
        progress: 1,
      );

      await _pollUntilTerminal(create.id);
    } on DioException catch (e) {
      if (e.type == DioExceptionType.cancel || _cancelled) {
        state = state.copyWith(status: 'cancelled', error: null);
        return;
      }
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

  Future<void> startPollingExisting(String readId) async {
    _cancelled = false;
    _cancelToken?.cancel('restart');
    _cancelToken = null;

    state = state.copyWith(
      status: 'polling',
      progress: 1,
      readId: readId,
      pollAttempt: 0,
      maxAttempts: 60,
      error: null,
    );

    try {
      await _pollUntilTerminal(readId);
    } on DioException catch (e) {
      if (e.type == DioExceptionType.cancel || _cancelled) {
        state = state.copyWith(status: 'cancelled', error: null);
        return;
      }
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

  Future<void> _pollUntilTerminal(String readId) async {
    final api = ref.read(palmReadsApiProvider);

    final maxAttempts = state.maxAttempts;
    for (var i = 0; i < maxAttempts; i++) {
      if (_cancelled) {
        state = state.copyWith(status: 'cancelled', error: null);
        return;
      }

      state = state.copyWith(pollAttempt: i + 1);
      final detail = await api.getPalmRead(readId);
      state = state.copyWith(lastDetail: detail);

      if (detail.status == 'completed') {
        state = state.copyWith(status: 'completed');
        return;
      }
      if (detail.status == 'failed') {
        final friendly = _friendlyFailureReason(detail.failureReason);
        state = state.copyWith(
          status: 'failed',
          error: friendly ?? 'Analysis failed',
        );
        return;
      }

      await Future<void>.delayed(
        const Duration(seconds: AppConfig.pollIntervalSeconds),
      );
    }

    state = state.copyWith(
      status: 'failed',
      error: 'Timed out while waiting for result',
    );
  }

  void cancel() {
    _cancelled = true;
    _cancelToken?.cancel('cancelled');
    state = state.copyWith(status: 'cancelled', error: null);
  }

  void reset() {
    _cancelled = false;
    _cancelToken?.cancel('reset');
    _cancelToken = null;
    state = const UploadState();
  }

  static String? _friendlyFailureReason(String? reason) {
    if (reason == null) return null;
    final r = reason.trim();
    if (r.isEmpty) return null;

    final lower = r.toLowerCase();
    if (lower.contains('hand_not_detected')) {
      return 'No hand detected. Please retake your photo with a clear palm in frame.';
    }
    if (lower.contains('blur')) {
      return 'Image looks blurry. Please retake with better focus.';
    }
    return r;
  }
}
