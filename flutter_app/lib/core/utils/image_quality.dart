import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

import '../../features/capture/domain/capture_quality_result.dart';

class ImageQuality {
  static const double minBrightness = 60.0;
  static const double maxBrightness = 210.0;
  static const double minBlurVariance = 35.0;
  static const int maxAnalysisLongSide = 640;

  static Future<CaptureQualityResult> evaluateAsync(Uint8List bytes) async {
    final map = await compute(_evaluateImageQualityMap, bytes);
    return CaptureQualityResult.fromMap(map);
  }

  static CaptureQualityResult evaluate(Uint8List bytes) {
    return CaptureQualityResult.fromMap(_evaluateImageQualityMap(bytes));
  }
}

Map<String, dynamic> _failedQualityMap() {
  return const CaptureQualityResult(
    brightness: 0,
    blurVariance: 0,
    palmCoverage: 0,
    centerOffset: 1,
    isBrightnessOk: false,
    isBlurOk: false,
    isPalmSizeOk: false,
    isCentered: false,
  ).toMap();
}

Map<String, dynamic> _evaluateImageQualityMap(Uint8List bytes) {
  try {
    final decoded = img.decodeImage(bytes);
    if (decoded == null) {
      return _failedQualityMap();
    }

    var working = decoded;
    final longSide = math.max(decoded.width, decoded.height);
    if (longSide > ImageQuality.maxAnalysisLongSide) {
      final scale = ImageQuality.maxAnalysisLongSide / longSide;
      final targetWidth = math.max(1, (decoded.width * scale).round());
      final targetHeight = math.max(1, (decoded.height * scale).round());
      working = img.copyResize(
        decoded,
        width: targetWidth,
        height: targetHeight,
        interpolation: img.Interpolation.linear,
      );
    }

    final gray = img.grayscale(working);
    final width = gray.width;
    final height = gray.height;

    double brightnessSum = 0;
    final luminance = List<double>.filled(width * height, 0);

    for (var y = 0; y < height; y++) {
      for (var x = 0; x < width; x++) {
        final pixel = gray.getPixel(x, y);
        final value = pixel.r.toDouble();
        final idx = y * width + x;
        luminance[idx] = value;
        brightnessSum += value;
      }
    }

    final meanBrightness = brightnessSum / (width * height);

    // 3x3 Laplacian kernel variance as blur score proxy.
    const kernel = [
      [0.0, 1.0, 0.0],
      [1.0, -4.0, 1.0],
      [0.0, 1.0, 0.0],
    ];

    var lapMean = 0.0;
    var lapM2 = 0.0;
    var lapCount = 0;

    for (var y = 1; y < height - 1; y++) {
      for (var x = 1; x < width - 1; x++) {
        var sum = 0.0;
        for (var ky = -1; ky <= 1; ky++) {
          for (var kx = -1; kx <= 1; kx++) {
            final p = luminance[(y + ky) * width + (x + kx)];
            sum += p * kernel[ky + 1][kx + 1];
          }
        }
        lapCount++;
        final delta = sum - lapMean;
        lapMean += delta / lapCount;
        lapM2 += delta * (sum - lapMean);
      }
    }

    final variance = lapCount > 1 ? lapM2 / lapCount : 0.0;

    final isBrightnessOk = meanBrightness >= ImageQuality.minBrightness &&
        meanBrightness <= ImageQuality.maxBrightness;
    final isBlurOk = variance >= ImageQuality.minBlurVariance;

    var skinPixels = 0;
    var minX = width;
    var minY = height;
    var maxX = 0;
    var maxY = 0;

    for (var y = 0; y < height; y++) {
      for (var x = 0; x < width; x++) {
        final pixel = working.getPixel(x, y);
        final r = pixel.r.toDouble();
        final g = pixel.g.toDouble();
        final b = pixel.b.toDouble();
        final maxChannel = math.max(r, math.max(g, b));
        final minChannel = math.min(r, math.min(g, b));

        // Simple "likely skin" heuristic used only to estimate palm coverage.
        // This intentionally aims to be inclusive across different skin tones
        // and lighting (flash vs ambient), to avoid false "not a hand" warnings.
        final looksLikeSkinRgb = r > 60 &&
            g > 30 &&
            b > 15 &&
            (maxChannel - minChannel) > 10 &&
            r >= g &&
            r >= b;

        // YCbCr skin range (approx). Works better than raw RGB thresholds in
        // many lighting conditions.
        final cb = 128 - (0.168736 * r) - (0.331264 * g) + (0.5 * b);
        final cr = 128 + (0.5 * r) - (0.418688 * g) - (0.081312 * b);
        final looksLikeSkinYCbCr =
            (cb >= 70 && cb <= 140) && (cr >= 130 && cr <= 185);

        final looksLikeSkin = looksLikeSkinRgb || looksLikeSkinYCbCr;

        if (!looksLikeSkin) {
          continue;
        }

        skinPixels++;
        if (x < minX) minX = x;
        if (y < minY) minY = y;
        if (x > maxX) maxX = x;
        if (y > maxY) maxY = y;
      }
    }

    final palmCoverage = (skinPixels / (width * height)).clamp(0.0, 1.0);
    final bboxCenterX = (minX + maxX) / 2.0;
    final bboxCenterY = (minY + maxY) / 2.0;
    final imageCenterX = width / 2.0;
    final imageCenterY = height / 2.0;
    final centerOffset = skinPixels == 0
        ? 1.0
        : (math.sqrt(math.pow(bboxCenterX - imageCenterX, 2) +
                    math.pow(bboxCenterY - imageCenterY, 2)) /
                math.max(width, height))
            .toDouble();
    final isPalmSizeOk = palmCoverage >= 0.15 && palmCoverage <= 0.80;
    final isCentered = centerOffset <= 0.20;

    return CaptureQualityResult(
      brightness: meanBrightness,
      blurVariance: variance,
      palmCoverage: palmCoverage,
      centerOffset: centerOffset,
      isBrightnessOk: isBrightnessOk,
      isBlurOk: isBlurOk,
      isPalmSizeOk: isPalmSizeOk,
      isCentered: isCentered,
    ).toMap();
  } catch (_) {
    return _failedQualityMap();
  }
}
