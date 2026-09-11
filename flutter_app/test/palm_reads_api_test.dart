import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:palm_read_mobile/features/result/data/palm_reads_api.dart';

class _RecordingAdapter implements HttpClientAdapter {
  Uint8List? requestBody;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    if (requestStream != null) {
      final chunks = await requestStream.toList();
      requestBody = Uint8List.fromList(
        chunks.expand((chunk) => chunk).toList(),
      );
    }

    return ResponseBody.fromString(
      '{"id":"read_123","status":"queued","correlation_id":"corr_123"}',
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  test('creates a byte-backed multipart upload without a file path', () async {
    final adapter = _RecordingAdapter();
    final dio = Dio(BaseOptions(baseUrl: 'https://example.test'))
      ..httpClientAdapter = adapter;

    final response = await PalmReadsApi(dio).createPalmRead(
      imageBytes: Uint8List.fromList([0x01, 0x02, 0x03]),
      filename: 'hand.jpg',
      handednessHint: 'left',
    );

    expect(response.id, 'read_123');
    expect(adapter.requestBody, isNotNull);
    final body = adapter.requestBody!;
    expect(
        _containsBytes(body, Uint8List.fromList([0x01, 0x02, 0x03])), isTrue);
    expect(String.fromCharCodes(body), contains('filename="hand.jpg"'));
    expect(String.fromCharCodes(body), contains('handedness_hint'));
  });
}

bool _containsBytes(Uint8List haystack, Uint8List needle) {
  for (var start = 0; start <= haystack.length - needle.length; start++) {
    var matches = true;
    for (var offset = 0; offset < needle.length; offset++) {
      if (haystack[start + offset] != needle[offset]) {
        matches = false;
        break;
      }
    }
    if (matches) return true;
  }
  return false;
}
