import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:palm_read_mobile/app.dart';
import 'package:palm_read_mobile/features/capture/presentation/capture_screen.dart';
import 'package:palm_read_mobile/features/capture/presentation/preview_screen.dart';
import 'package:palm_read_mobile/features/capture/domain/capture_quality_result.dart';
import 'package:palm_read_mobile/features/capture/state/capture_controller.dart';
import 'package:palm_read_mobile/features/history/presentation/history_screen.dart';
import 'package:palm_read_mobile/features/history/state/history_controller.dart';
import 'package:palm_read_mobile/features/result/domain/palm_read_models.dart';
import 'package:palm_read_mobile/features/result/presentation/result_screen.dart';
import 'package:palm_read_mobile/features/result/state/palm_read_providers.dart';
import 'package:palm_read_mobile/shared/widgets/responsive_page.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('desktop sidebar exposes primary navigation and account access',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1440, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PalmDesktopSidebar(
            index: 0,
            onSelect: (_) {},
            onAccount: () {},
          ),
        ),
      ),
    );

    expect(find.text('PalmRead'), findsOneWidget);
    expect(find.text('Capture'), findsOneWidget);
    expect(find.text('History'), findsOneWidget);
    expect(find.text('Account & settings'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('result keeps complete line analysis readable at desktop sizes',
      (tester) async {
    final detail = PalmReadDetail(
      id: 'read-1',
      status: 'completed',
      handedness: 'left',
      handSignatureHash: null,
      readingText: 'A grounded reading for a steady set of priorities.',
      resultJson: {
        'narrative': 'A grounded reading for a steady set of priorities.',
        'suggestions': ['Protect one useful habit.'],
        'line_situations': [
          _line('life', 'Your rhythm is steady.'),
          _line('head', 'You think carefully.'),
          _line('heart', 'You value trust.'),
          _line('fate', 'Your direction develops through effort.'),
          _line('sun', 'Your strengths can be visible.'),
        ],
      },
      processingMs: 1,
      failureReason: null,
      createdAt: DateTime(2026, 9, 12),
    );

    for (final size in const [Size(1024, 900), Size(1440, 900)]) {
      await tester.binding.setSurfaceSize(size);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            palmReadDetailProvider('read-1')
                .overrideWith((ref) async => detail),
            palmImageBytesProvider('read-1').overrideWith((ref) async => null),
          ],
          child: const MaterialApp(home: ResultScreen(readId: 'read-1')),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Detailed Analysis'), findsOneWidget);
      expect(find.text('Life Line Analysis'), findsOneWidget);
      expect(find.text('Fate Line Analysis'), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('result remains overflow-free on a narrow mobile viewport',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final detail = PalmReadDetail(
      id: 'read-2',
      status: 'completed',
      handedness: 'right',
      handSignatureHash: null,
      readingText: 'A reflective reading.',
      resultJson: {
        'line_situations': [
          _line('life', 'A long line with a thoughtful observation.'),
          _line('head', 'A careful decision style.'),
          _line('heart', 'A preference for trust.'),
          _line('fate', 'A direction shaped by effort.'),
          _line('sun', 'Visibility may grow over time.'),
        ],
      },
      processingMs: 1,
      failureReason: null,
      createdAt: DateTime(2026, 9, 12),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          palmReadDetailProvider('read-2').overrideWith((ref) async => detail),
          palmImageBytesProvider('read-2').overrideWith((ref) async => null),
        ],
        child: const MaterialApp(home: ResultScreen(readId: 'read-2')),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Detailed Analysis'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('shared page container centers wide content', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1440, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: PalmPageContainer(
            child: Text('Centered content'),
          ),
        ),
      ),
    );

    expect(find.text('Centered content'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('capture layout stays usable at desktop and mobile widths',
      (tester) async {
    for (final size in const [
      Size(390, 844),
      Size(1024, 900),
      Size(1440, 900)
    ]) {
      await tester.binding.setSurfaceSize(size);
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(home: CaptureScreen()),
        ),
      );
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.text('New Reading'), findsOneWidget);
      expect(find.text('Use Camera'), findsOneWidget);
      expect(find.text('Choose Photo'), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
    addTearDown(() => tester.binding.setSurfaceSize(null));
  });

  testWidgets('preview layout remains overflow-free across viewports',
      (tester) async {
    for (final size in const [
      Size(390, 844),
      Size(1024, 900),
      Size(1440, 900),
    ]) {
      final controller = CaptureController();
      controller.state = CaptureState(
        imageBytes: _samplePng,
        imageFilename: 'palm.png',
        quality: const CaptureQualityResult(
          brightness: 120,
          blurVariance: 80,
          palmCoverage: 0.3,
          centerOffset: 0.05,
          isBrightnessOk: true,
          isBlurOk: true,
          isPalmSizeOk: true,
          isCentered: true,
        ),
        handDetected: true,
        handedness: 'right',
      );
      await tester.binding.setSurfaceSize(size);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            captureControllerProvider.overrideWith((ref) => controller),
          ],
          child: const MaterialApp(home: PreviewScreen()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Verify Photo'), findsOneWidget);
      expect(find.text('Upload for Analysis'), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
    addTearDown(() => tester.binding.setSurfaceSize(null));
  });

  testWidgets('history layout uses a wide grid without mobile overflow',
      (tester) async {
    for (final size in const [
      Size(390, 844),
      Size(1024, 900),
      Size(1440, 900)
    ]) {
      await tester.binding.setSurfaceSize(size);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            palmHistoryProvider.overrideWith(
              (ref) async => const PalmReadHistoryPage(items: [], total: 0),
            ),
          ],
          child: const MaterialApp(home: HistoryScreen()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('History'), findsOneWidget);
      expect(find.text('No readings yet.'), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
    addTearDown(() => tester.binding.setSurfaceSize(null));
  });
}

Map<String, String> _line(String key, String situation) {
  return {
    'key': key,
    'title': '$key line',
    'situation': situation,
    'prediction': 'A useful pattern may develop.',
    'suggestion': 'Keep one practical habit.',
  };
}

final Uint8List _samplePng = base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=');
