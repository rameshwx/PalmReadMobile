class CaptureQualityResult {
  const CaptureQualityResult({
    required this.brightness,
    required this.blurVariance,
    required this.palmCoverage,
    required this.centerOffset,
    required this.isBrightnessOk,
    required this.isBlurOk,
    required this.isPalmSizeOk,
    required this.isCentered,
  });

  final double brightness;
  final double blurVariance;
  final double palmCoverage;
  final double centerOffset;
  final bool isBrightnessOk;
  final bool isBlurOk;
  final bool isPalmSizeOk;
  final bool isCentered;

  bool get passesHardGates => isBrightnessOk && isBlurOk;

  factory CaptureQualityResult.fromMap(Map<String, dynamic> map) {
    return CaptureQualityResult(
      brightness: (map['brightness'] as num?)?.toDouble() ?? 0,
      blurVariance: (map['blurVariance'] as num?)?.toDouble() ?? 0,
      palmCoverage: (map['palmCoverage'] as num?)?.toDouble() ?? 0,
      centerOffset: (map['centerOffset'] as num?)?.toDouble() ?? 1,
      isBrightnessOk: map['isBrightnessOk'] == true,
      isBlurOk: map['isBlurOk'] == true,
      isPalmSizeOk: map['isPalmSizeOk'] == true,
      isCentered: map['isCentered'] == true,
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'brightness': brightness,
      'blurVariance': blurVariance,
      'palmCoverage': palmCoverage,
      'centerOffset': centerOffset,
      'isBrightnessOk': isBrightnessOk,
      'isBlurOk': isBlurOk,
      'isPalmSizeOk': isPalmSizeOk,
      'isCentered': isCentered,
    };
  }
}
