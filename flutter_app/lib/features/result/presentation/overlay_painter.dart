import 'package:flutter/material.dart';

import '../domain/palm_read_models.dart';

class OverlayPainter extends CustomPainter {
  OverlayPainter({required this.overlay});

  final PalmOverlay overlay;

  static const Map<String, Color> lineColors = {
    'life': Color(0xFF2E7D32),
    'head': Color(0xFF1565C0),
    'heart': Color(0xFFC62828),
    'fate': Color(0xFF6A1B9A),
    'sun': Color(0xFFEF6C00),
  };

  @override
  void paint(Canvas canvas, Size size) {
    if (overlay.imageWidth <= 0 || overlay.imageHeight <= 0) {
      return;
    }

    final scaleX = size.width / overlay.imageWidth;
    final scaleY = size.height / overlay.imageHeight;

    for (final line in overlay.lines) {
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
      path.moveTo(first.x * scaleX, first.y * scaleY);

      for (var i = 1; i < line.points.length; i++) {
        final p = line.points[i];
        path.lineTo(p.x * scaleX, p.y * scaleY);
      }

      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant OverlayPainter oldDelegate) {
    return oldDelegate.overlay != overlay;
  }
}
