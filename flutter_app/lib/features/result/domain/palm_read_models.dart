class PalmPoint {
  const PalmPoint({required this.x, required this.y});

  final double x;
  final double y;

  factory PalmPoint.fromJson(Map<String, dynamic> json) {
    return PalmPoint(
      x: (json['x'] as num).toDouble(),
      y: (json['y'] as num).toDouble(),
    );
  }
}

class PalmLine {
  const PalmLine({
    required this.key,
    required this.confidence,
    required this.points,
    required this.missing,
  });

  final String key;
  final double confidence;
  final List<PalmPoint> points;
  final bool missing;

  factory PalmLine.fromJson(Map<String, dynamic> json) {
    final points = (json['points'] as List<dynamic>? ?? [])
        .map((p) => PalmPoint.fromJson(p as Map<String, dynamic>))
        .toList();

    return PalmLine(
      key: json['key'] as String,
      confidence: (json['confidence'] as num?)?.toDouble() ?? 0.0,
      points: points,
      missing: json['missing'] as bool? ?? false,
    );
  }
}

class PalmOverlay {
  const PalmOverlay({
    required this.imageWidth,
    required this.imageHeight,
    required this.lines,
    required this.legend,
    required this.resultId,
    required this.handSignatureHash,
  });

  final int imageWidth;
  final int imageHeight;
  final List<PalmLine> lines;
  final Map<String, String> legend;
  final String resultId;
  final String? handSignatureHash;

  factory PalmOverlay.fromJson(Map<String, dynamic> json) {
    final image = json['image'] as Map<String, dynamic>? ?? const {};
    final legendRaw = json['legend'] as Map<String, dynamic>? ?? const {};

    return PalmOverlay(
      imageWidth: (image['width'] as num?)?.toInt() ?? 0,
      imageHeight: (image['height'] as num?)?.toInt() ?? 0,
      lines: (json['lines'] as List<dynamic>? ?? [])
          .map((line) => PalmLine.fromJson(line as Map<String, dynamic>))
          .toList(),
      legend: legendRaw.map((key, value) => MapEntry(key, value.toString())),
      resultId: json['result_id']?.toString() ?? '',
      handSignatureHash: json['hand_signature_hash']?.toString(),
    );
  }
}

class PalmReadCreateResponse {
  const PalmReadCreateResponse({
    required this.id,
    required this.status,
    required this.correlationId,
  });

  final String id;
  final String status;
  final String correlationId;

  factory PalmReadCreateResponse.fromJson(Map<String, dynamic> json) {
    return PalmReadCreateResponse(
      id: json['id'].toString(),
      status: json['status'] as String,
      correlationId: json['correlation_id'] as String? ?? '',
    );
  }
}

class PalmReadDetail {
  const PalmReadDetail({
    required this.id,
    required this.status,
    required this.handedness,
    required this.handSignatureHash,
    required this.readingText,
    required this.resultJson,
    required this.processingMs,
    required this.failureReason,
    required this.createdAt,
  });

  final String id;
  final String status;
  final String handedness;
  final String? handSignatureHash;
  final String? readingText;
  final Map<String, dynamic>? resultJson;
  final int? processingMs;
  final String? failureReason;
  final DateTime? createdAt;

  bool get isTerminal => status == 'completed' || status == 'failed';

  factory PalmReadDetail.fromJson(Map<String, dynamic> json) {
    return PalmReadDetail(
      id: json['id'].toString(),
      status: json['status'] as String? ?? 'unknown',
      handedness: json['handedness'] as String? ?? 'unknown',
      handSignatureHash: json['hand_signature_hash']?.toString(),
      readingText: json['reading_text']?.toString(),
      resultJson: json['result_json'] as Map<String, dynamic>?,
      processingMs: (json['processing_ms'] as num?)?.toInt(),
      failureReason: json['failure_reason']?.toString(),
      createdAt: json['created_at'] == null
          ? null
          : DateTime.tryParse(json['created_at'].toString()),
    );
  }
}

class PalmReadHistoryPage {
  const PalmReadHistoryPage({required this.items, required this.total});

  final List<PalmReadDetail> items;
  final int total;

  factory PalmReadHistoryPage.fromJson(Map<String, dynamic> json) {
    final items = (json['data'] as List<dynamic>? ?? [])
        .whereType<Map<String, dynamic>>()
        .map(PalmReadDetail.fromJson)
        .toList();
    return PalmReadHistoryPage(
      items: items,
      total: (json['total'] as num?)?.toInt() ?? items.length,
    );
  }
}
