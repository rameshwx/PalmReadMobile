import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../domain/palm_read_models.dart';

class OverlayPainter extends CustomPainter {
  OverlayPainter({
    required this.overlay,
    this.visibleKeys,
    this.fit = BoxFit.contain,
  });

  final PalmOverlay overlay;
  final Set<String>? visibleKeys;
  final BoxFit fit;

  static const Map<String, Color> lineColors = {
    'life': Color(0xFFEF4444),
    'head': Color(0xFF3B82F6),
    'heart': Color(0xFF10B981),
    'fate': Color(0xFFF59E0B),
    'sun': Color(0xFFA855F7),
  };

  @override
  void paint(Canvas canvas, Size size) {
    if (overlay.imageWidth <= 0 || overlay.imageHeight <= 0) {
      return;
    }

    final imageW = overlay.imageWidth.toDouble();
    final imageH = overlay.imageHeight.toDouble();

    double scaleX;
    double scaleY;
    double dx;
    double dy;

    switch (fit) {
      case BoxFit.cover:
      case BoxFit.contain:
        final scale = fit == BoxFit.cover
            ? math.max(size.width / imageW, size.height / imageH)
            : math.min(size.width / imageW, size.height / imageH);
        scaleX = scale;
        scaleY = scale;
        dx = (size.width - (imageW * scale)) / 2.0;
        dy = (size.height - (imageH * scale)) / 2.0;
        break;
      case BoxFit.fill:
      default:
        scaleX = size.width / imageW;
        scaleY = size.height / imageH;
        dx = 0;
        dy = 0;
        break;
    }

    for (final line in overlay.lines) {
      if (visibleKeys != null && !visibleKeys!.contains(line.key)) {
        continue;
      }
      if (line.points.length < 2) {
        continue;
      }

      final color = lineColors[line.key] ?? Colors.white;
      final paint = Paint()
        ..color = color.withValues(
            alpha: (0.35 + (line.confidence * 0.65)).clamp(0.35, 1.0))
        ..strokeWidth = 2.5
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;

      final path = Path();
      final first = line.points.first;
      path.moveTo(dx + (first.x * scaleX), dy + (first.y * scaleY));

      for (var i = 1; i < line.points.length; i++) {
        final p = line.points[i];
        path.lineTo(dx + (p.x * scaleX), dy + (p.y * scaleY));
      }

      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant OverlayPainter oldDelegate) {
    return oldDelegate.overlay != overlay ||
        !setEquals(oldDelegate.visibleKeys, visibleKeys) ||
        oldDelegate.fit != fit;
  }
}
