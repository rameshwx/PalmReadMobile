import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:palm_read_mobile/features/result/domain/palm_read_models.dart';
import 'package:palm_read_mobile/features/result/presentation/overlay_painter.dart';

PalmOverlay _sampleOverlay() {
  return PalmOverlay(
    imageWidth: 1000,
    imageHeight: 1500,
    resultId: 'read_123',
    handSignatureHash: 'abc123',
    legend: const {
      'life': '#2E7D32',
      'head': '#1565C0',
      'heart': '#C62828',
      'fate': '#6A1B9A',
      'sun': '#EF6C00',
    },
    lines: const [
      PalmLine(
        key: 'life',
        confidence: 0.8,
        missing: false,
        points: [
          PalmPoint(x: 100, y: 200),
          PalmPoint(x: 200, y: 350),
          PalmPoint(x: 320, y: 500),
        ],
      ),
      PalmLine(
        key: 'head',
        confidence: 0.6,
        missing: false,
        points: [
          PalmPoint(x: 120, y: 600),
          PalmPoint(x: 300, y: 620),
        ],
      ),
      PalmLine(
        key: 'sun',
        confidence: 0.1,
        missing: true,
        points: [],
      ),
    ],
  );
}

void main() {
  testWidgets('OverlayPainter renders sample polylines without exceptions',
      (tester) async {
    final overlay = _sampleOverlay();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CustomPaint(
            painter: OverlayPainter(overlay: overlay),
            child: const SizedBox(width: 300, height: 450),
          ),
        ),
      ),
    );

    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  test('OverlayPainter shouldRepaint changes with new overlay payload', () {
    final overlayA = _sampleOverlay();
    final overlayB = PalmOverlay(
      imageWidth: overlayA.imageWidth,
      imageHeight: overlayA.imageHeight,
      lines: [...overlayA.lines, ...overlayA.lines.take(1)],
      legend: overlayA.legend,
      resultId: overlayA.resultId,
      handSignatureHash: overlayA.handSignatureHash,
    );

    final painterA = OverlayPainter(overlay: overlayA);
    final painterB = OverlayPainter(overlay: overlayB);

    expect(painterB.shouldRepaint(painterA), isTrue);
  });
}
