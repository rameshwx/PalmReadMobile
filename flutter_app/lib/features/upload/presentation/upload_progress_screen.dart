import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/theme/palm_tokens.dart';
import '../../capture/state/capture_controller.dart';
import '../../result/presentation/result_screen.dart';
import '../state/upload_controller.dart';

class UploadProgressScreen extends ConsumerStatefulWidget {
  const UploadProgressScreen({super.key, this.existingReadId});

  final String? existingReadId;

  @override
  ConsumerState<UploadProgressScreen> createState() =>
      _UploadProgressScreenState();
}

class _UploadProgressScreenState extends ConsumerState<UploadProgressScreen>
    with SingleTickerProviderStateMixin {
  bool _started = false;
  late final AnimationController _spin;

  @override
  void initState() {
    super.initState();
    _spin =
        AnimationController(vsync: this, duration: const Duration(seconds: 8))
          ..repeat();

    ref.listen<UploadState>(uploadControllerProvider, (prev, next) {
      if (!mounted) return;

      if (next.status == 'completed' && next.readId != null) {
        final readId = next.readId!;
        final capture = ref.read(captureControllerProvider);
        if (capture.imageFile != null) {
          ref.read(captureControllerProvider.notifier).clear();
        }
        ref.read(uploadControllerProvider.notifier).reset();

        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => ResultScreen(readId: readId)),
          (route) => route.isFirst,
        );
      }

      if (next.status == 'failed' &&
          next.error != null &&
          next.error!.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(next.error!)),
        );
      }
    });
  }

  @override
  void dispose() {
    _spin.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final notifier = ref.read(uploadControllerProvider.notifier);
      if (widget.existingReadId != null && widget.existingReadId!.isNotEmpty) {
        await notifier.startPollingExisting(widget.existingReadId!);
      } else {
        await notifier.startUpload();
      }
    });
  }

  double _displayProgress(UploadState s) {
    final status = s.status;
    if (status == 'completed') return 1;
    if (status == 'uploading') return (s.progress * 0.30).clamp(0.0, 0.30);
    if (status == 'polling') {
      final frac = s.maxAttempts <= 0 ? 0.0 : (s.pollAttempt / s.maxAttempts);
      return (0.30 + (frac * 0.65)).clamp(0.30, 0.95);
    }
    return 0.0;
  }

  String _statusTitle(UploadState s) {
    switch (s.status) {
      case 'uploading':
        return 'Uploading...';
      case 'polling':
        return 'Analyzing Lines...';
      case 'completed':
        return 'Done';
      case 'cancelled':
        return 'Cancelled';
      case 'failed':
        return 'Something went wrong';
      default:
        return 'Analyzing Lines...';
    }
  }

  String _statusSubtitle(UploadState s) {
    if (s.status == 'uploading') {
      return 'Preparing your image for analysis.';
    }
    if (s.status == 'polling') {
      return 'Mapping your Heart, Head, and Life lines for deeper insights.';
    }
    if (s.status == 'failed') {
      return 'Please try again.';
    }
    if (s.status == 'cancelled') {
      return 'You can start a new reading anytime.';
    }
    return 'Please do not close the app while we process your reading.';
  }

  @override
  Widget build(BuildContext context) {
    final upload = ref.watch(uploadControllerProvider);
    final capture = ref.watch(captureControllerProvider);
    final text = Theme.of(context).textTheme;

    final progress = _displayProgress(upload);
    final percent = (progress * 100).round().clamp(0, 100);
    final id = (upload.readId ?? widget.existingReadId ?? '').trim();
    final idShort = id.isEmpty
        ? '—'
        : '#${id.substring(0, math.min(5, id.length)).toUpperCase()}';

    final showQueued = upload.status != 'idle';
    final showPolling = upload.status == 'polling';

    return Scaffold(
      body: Stack(
        children: [
          const Positioned.fill(child: _AnalyzingBackground()),
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 14, 20, 8),
                  child: Row(
                    children: [
                      Row(
                        children: [
                          Icon(Icons.psychology,
                              color: PalmTokens.primaryDark
                                  .withValues(alpha: 0.9)),
                          const SizedBox(width: 8),
                          Text(
                            'PalmRead',
                            style: text.titleMedium?.copyWith(
                              fontWeight: FontWeight.w900,
                              letterSpacing: -0.2,
                            ),
                          ),
                        ],
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: PalmTokens.surface.withValues(alpha: 0.65),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                              color: Colors.black.withValues(alpha: 0.06)),
                        ),
                        child: Text(
                          'ID: $idShort',
                          style: text.labelSmall?.copyWith(
                            fontFamily: 'monospace',
                            fontWeight: FontWeight.w800,
                            color: PalmTokens.textSub,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: 320,
                          child: AspectRatio(
                            aspectRatio: 1,
                            child: Stack(
                              children: [
                                Positioned.fill(
                                  child: DecoratedBox(
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: PalmTokens.primary
                                            .withValues(alpha: 0.20),
                                      ),
                                    ),
                                  ),
                                ),
                                Positioned.fill(
                                  child: Padding(
                                    padding: const EdgeInsets.all(14),
                                    child: DecoratedBox(
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: PalmTokens.primary
                                              .withValues(alpha: 0.10),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                Positioned.fill(
                                  child: Padding(
                                    padding: const EdgeInsets.all(22),
                                    child: Container(
                                      decoration: BoxDecoration(
                                        color: PalmTokens.surface,
                                        shape: BoxShape.circle,
                                        boxShadow: [
                                          BoxShadow(
                                            color: PalmTokens.primary
                                                .withValues(alpha: 0.10),
                                            blurRadius: 24,
                                            offset: const Offset(0, 14),
                                          ),
                                        ],
                                        border: Border.all(
                                          color: Colors.black
                                              .withValues(alpha: 0.06),
                                        ),
                                      ),
                                      child: ClipOval(
                                        child: Stack(
                                          children: [
                                            Positioned.fill(
                                              child: capture.imageFile == null
                                                  ? Container(
                                                      color: Colors.black
                                                          .withValues(
                                                              alpha: 0.04),
                                                    )
                                                  : ColorFiltered(
                                                      colorFilter:
                                                          const ColorFilter
                                                              .matrix([
                                                        0.2126,
                                                        0.7152,
                                                        0.0722,
                                                        0,
                                                        0,
                                                        0.2126,
                                                        0.7152,
                                                        0.0722,
                                                        0,
                                                        0,
                                                        0.2126,
                                                        0.7152,
                                                        0.0722,
                                                        0,
                                                        0,
                                                        0,
                                                        0,
                                                        0,
                                                        1,
                                                        0,
                                                      ]),
                                                      child: Image.file(
                                                        capture.imageFile!,
                                                        fit: BoxFit.cover,
                                                      ),
                                                    ),
                                            ),
                                            Positioned.fill(
                                              child: AnimatedBuilder(
                                                animation: _spin,
                                                builder: (context, _) {
                                                  return Transform.rotate(
                                                    angle: _spin.value *
                                                        math.pi *
                                                        2,
                                                    child: Padding(
                                                      padding:
                                                          const EdgeInsets.all(
                                                              10),
                                                      child: DecoratedBox(
                                                        decoration:
                                                            BoxDecoration(
                                                          shape:
                                                              BoxShape.circle,
                                                          border: Border.all(
                                                            color: PalmTokens
                                                                .primary
                                                                .withValues(
                                                                    alpha:
                                                                        0.35),
                                                            width: 2,
                                                            style: BorderStyle
                                                                .solid,
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                  );
                                                },
                                              ),
                                            ),
                                            Positioned.fill(
                                              child: _CircleScanOverlay(
                                                progress: _spin,
                                              ),
                                            ),
                                            Center(
                                              child: Container(
                                                padding:
                                                    const EdgeInsets.all(16),
                                                decoration: BoxDecoration(
                                                  color: PalmTokens.surface
                                                      .withValues(alpha: 0.90),
                                                  borderRadius:
                                                      BorderRadius.circular(18),
                                                  border: Border.all(
                                                    color: Colors.black
                                                        .withValues(
                                                            alpha: 0.06),
                                                  ),
                                                  boxShadow:
                                                      PalmTokens.shadowCard,
                                                ),
                                                child: const Icon(
                                                  Icons.fingerprint,
                                                  color: PalmTokens.primaryDark,
                                                  size: 44,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                if (showPolling)
                                  Positioned(
                                    right: 0,
                                    top: 36,
                                    child: _FloatingPill(
                                      dot: true,
                                      label: 'Polling...',
                                    ),
                                  ),
                                if (showQueued)
                                  Positioned(
                                    left: 0,
                                    bottom: 64,
                                    child: _FloatingPill(
                                      dot: false,
                                      label: upload.status == 'uploading'
                                          ? 'Uploading'
                                          : 'Image Queued',
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 26),
                        Text(
                          _statusTitle(upload),
                          textAlign: TextAlign.center,
                          style: text.headlineMedium?.copyWith(
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.4,
                          ),
                        ),
                        const SizedBox(height: 10),
                        SizedBox(
                          width: 320,
                          child: Text(
                            _statusSubtitle(upload),
                            textAlign: TextAlign.center,
                            style: text.bodyMedium?.copyWith(
                              color: PalmTokens.textSub,
                              fontWeight: FontWeight.w600,
                              height: 1.35,
                            ),
                          ),
                        ),
                        const SizedBox(height: 26),
                        SizedBox(
                          width: 360,
                          child: Column(
                            children: [
                              Row(
                                children: [
                                  Text(
                                    upload.status == 'failed'
                                        ? 'Failed'
                                        : 'Processing',
                                    style: text.labelLarge?.copyWith(
                                      fontWeight: FontWeight.w900,
                                      color: PalmTokens.primaryDark,
                                    ),
                                  ),
                                  const Spacer(),
                                  Text(
                                    '$percent%',
                                    style: text.labelLarge?.copyWith(
                                      fontWeight: FontWeight.w900,
                                      color: PalmTokens.textSub,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(999),
                                child: Container(
                                  height: 12,
                                  color: Colors.black.withValues(alpha: 0.05),
                                  child: Align(
                                    alignment: Alignment.centerLeft,
                                    child: FractionallySizedBox(
                                      widthFactor: progress,
                                      child: Container(
                                        decoration: const BoxDecoration(
                                          color: PalmTokens.primary,
                                          borderRadius: BorderRadius.all(
                                              Radius.circular(999)),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 30),
                        SizedBox(
                          width: 360,
                          child: OutlinedButton.icon(
                            onPressed: upload.status == 'completed'
                                ? null
                                : () {
                                    ref
                                        .read(uploadControllerProvider.notifier)
                                        .cancel();
                                    Navigator.of(context).pop();
                                  },
                            icon: const Icon(Icons.close),
                            label: const Text('Cancel Analysis'),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 18),
                              backgroundColor: PalmTokens.surface,
                              side: BorderSide(
                                  color: Colors.black.withValues(alpha: 0.08)),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(18),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),
                        Text(
                          'Please do not close the app while we process your reading.',
                          textAlign: TextAlign.center,
                          style: text.labelSmall?.copyWith(
                            color: PalmTokens.textSub.withValues(alpha: 0.45),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FloatingPill extends StatelessWidget {
  const _FloatingPill({required this.dot, required this.label});

  final bool dot;
  final String label;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return Transform.rotate(
      angle: dot ? 0.12 : -0.06,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: PalmTokens.surface,
          borderRadius: BorderRadius.circular(14),
          boxShadow: PalmTokens.shadowCard,
          border: Border.all(color: Colors.black.withValues(alpha: 0.05)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (dot) ...[
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: PalmTokens.primary,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
            ] else ...[
              const Icon(Icons.check_circle,
                  size: 14, color: PalmTokens.primaryDark),
              const SizedBox(width: 8),
            ],
            Text(
              label,
              style: text.labelLarge?.copyWith(
                fontWeight: FontWeight.w900,
                color: PalmTokens.textSub,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CircleScanOverlay extends StatelessWidget {
  const _CircleScanOverlay({required this.progress});

  final Animation<double> progress;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: progress,
      builder: (context, _) {
        final t = progress.value;
        return Align(
          alignment: Alignment(0, -1 + (2 * t)),
          child: Container(
            height: 90,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.transparent,
                  PalmTokens.primary.withValues(alpha: 0.55),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _AnalyzingBackground extends StatelessWidget {
  const _AnalyzingBackground();

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  PalmTokens.background,
                  PalmTokens.background.withValues(alpha: 0.96),
                ],
              ),
            ),
          ),
        ),
        Positioned(
          top: -120,
          right: -120,
          child: Container(
            width: 320,
            height: 320,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: PalmTokens.primary.withValues(alpha: 0.10),
            ),
          ),
        ),
        Positioned(
          top: 340,
          left: -120,
          child: Container(
            width: 380,
            height: 380,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: PalmTokens.primary.withValues(alpha: 0.06),
            ),
          ),
        ),
        Positioned.fill(
          child: IgnorePointer(
            child: CustomPaint(
              painter: _DotsPainter(seed: 7),
            ),
          ),
        ),
      ],
    );
  }
}

class _DotsPainter extends CustomPainter {
  _DotsPainter({required int seed}) : _rand = math.Random(seed);

  final math.Random _rand;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = PalmTokens.primary.withValues(alpha: 0.05);
    for (var i = 0; i < 180; i++) {
      final x = _rand.nextDouble() * size.width;
      final y = _rand.nextDouble() * size.height;
      canvas.drawCircle(Offset(x, y), 1.2, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
