import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as path;

import '../../../core/networking/dio_client.dart';
import '../domain/palm_read_models.dart';

final palmReadsApiProvider = Provider<PalmReadsApi>((ref) {
  return PalmReadsApi(ref.watch(dioProvider));
});

class PalmReadsApi {
  PalmReadsApi(this._dio);

  final Dio _dio;

  Future<PalmReadCreateResponse> createPalmRead({
    required File imageFile,
    required String handednessHint,
    ProgressCallback? onSendProgress,
    CancelToken? cancelToken,
  }) async {
    final formData = FormData.fromMap({
      'handedness_hint': handednessHint,
      'image': await MultipartFile.fromFile(
        imageFile.path,
        filename: path.basename(imageFile.path),
      ),
    });

    final response = await _dio.post<Map<String, dynamic>>(
      '/api/palm-reads',
      data: formData,
      onSendProgress: onSendProgress,
      cancelToken: cancelToken,
    );

    return PalmReadCreateResponse.fromJson(response.data!);
  }

  Future<PalmReadDetail> getPalmRead(String id) async {
    final response =
        await _dio.get<Map<String, dynamic>>('/api/palm-reads/$id');
    return PalmReadDetail.fromJson(response.data!);
  }

  Future<PalmOverlay> getOverlay(String id) async {
    final response =
        await _dio.get<Map<String, dynamic>>('/api/palm-reads/$id/overlay');
    return PalmOverlay.fromJson(response.data!);
  }

  Future<Uint8List?> getImageBytes(String id) async {
    final response = await _dio.get<List<int>>(
      '/api/palm-reads/$id/image',
      options: Options(responseType: ResponseType.bytes),
    );

    final bytes = response.data;
    if (bytes == null) {
      return null;
    }
    return Uint8List.fromList(bytes);
  }

  Future<PalmReadHistoryPage> listPalmReads({int page = 1}) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/api/palm-reads',
      queryParameters: {'page': page},
    );

    return PalmReadHistoryPage.fromJson(response.data ?? const {});
  }

  Future<void> submitFeedback({
    required String palmReadId,
    required bool isCorrect,
    String? note,
  }) async {
    await _dio.post('/api/palm-reads/$palmReadId/feedback', data: {
      'is_correct': isCorrect,
      'note': note,
    });
  }
}
