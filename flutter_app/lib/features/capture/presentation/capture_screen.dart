import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../shared/theme/palm_tokens.dart';
import '../state/capture_controller.dart';
import 'preview_screen.dart';

class CaptureScreen extends ConsumerStatefulWidget {
  const CaptureScreen({super.key});

  @override
  ConsumerState<CaptureScreen> createState() => _CaptureScreenState();
}

class _CaptureScreenState extends ConsumerState<CaptureScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _scanController;

  @override
  void initState() {
    super.initState();
    _scanController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();
  }

  @override
  void dispose() {
    _scanController.dispose();
    super.dispose();
  }

  Future<void> _pickFromCamera() async {
    final state = ref.read(captureControllerProvider);
    if (state.isEvaluating) return;

    final picker = ImagePicker();
    final file = await picker.pickImage(
      source: ImageSource.camera,
      preferredCameraDevice: CameraDevice.rear,
      imageQuality: 92,
      maxWidth: 1600,
      maxHeight: 1600,
    );

    if (file == null) return;

    await ref.read(captureControllerProvider.notifier).setImage(file);
    if (!mounted) return;

    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const PreviewScreen()),
    );
  }

  Future<void> _pickFromGallery() async {
    final state = ref.read(captureControllerProvider);
    if (state.isEvaluating) {
      return;
    }

    final picker = ImagePicker();
    final file = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 92,
      maxWidth: 1600,
      maxHeight: 1600,
    );

    if (file == null) {
      return;
    }

    await ref.read(captureControllerProvider.notifier).setImage(file);
    if (!mounted) {
      return;
    }

    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const PreviewScreen()),
    );
  }

  void _openHelp() {
    showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Photo tips'),
        content: const Text(
          'Keep your hand flat and centered. Use good lighting and avoid blur or shadows.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(captureControllerProvider);
    final quality = state.quality;
    final text = Theme.of(context).textTheme;

    final lightingOk = quality?.isBrightnessOk ?? false;
    final focusOk = quality?.isBlurOk ?? false;
    final centeredOk = quality?.isCentered ?? false;

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
          child: Column(
            children: [
              Row(
                children: [
                  if (Navigator.of(context).canPop())
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.arrow_back),
                    )
                  else
                    const SizedBox(width: 48, height: 48),
                  Expanded(
                    child: Column(
                      children: [
                        Text(
                          'New Reading',
                          style: text.titleLarge?.copyWith(
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.3,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                color: PalmTokens.primary,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'LIVE ANALYSIS',
                              style: text.labelSmall?.copyWith(
                                color: PalmTokens.primaryDark,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1.2,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: _openHelp,
                    icon: const Icon(Icons.help_outline),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Expanded(
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 420),
                    child: AspectRatio(
                      aspectRatio: 3 / 4,
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius:
                              BorderRadius.circular(PalmTokens.radiusXl),
                          color: const Color(0xFF0B1011),
                          boxShadow: PalmTokens.shadowCard,
                        ),
                        child: ClipRRect(
                          borderRadius:
                              BorderRadius.circular(PalmTokens.radiusXl),
                          child: Stack(
                            children: [
                              Positioned.fill(
                                child: DecoratedBox(
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                      colors: [
                                        Colors.black.withValues(alpha: 0.25),
                                        Colors.black.withValues(alpha: 0.55),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              Positioned.fill(
                                child: DecoratedBox(
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                      colors: [
                                        Colors.black.withValues(alpha: 0.08),
                                        Colors.black.withValues(alpha: 0.55),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              const Positioned.fill(
                                child: Padding(
                                  padding: EdgeInsets.all(22),
                                  child: CustomPaint(
                                    painter: _HandGuidePainter(),
                                  ),
                                ),
                              ),
                              Positioned.fill(
                                child: Padding(
                                  padding: const EdgeInsets.all(18),
                                  child: Stack(
                                    children: const [
                                      _CornerMarker(
                                          alignment: Alignment.topLeft),
                                      _CornerMarker(
                                          alignment: Alignment.topRight),
                                      _CornerMarker(
                                          alignment: Alignment.bottomLeft),
                                      _CornerMarker(
                                          alignment: Alignment.bottomRight),
                                    ],
                                  ),
                                ),
                              ),
                              Positioned.fill(
                                child: AnimatedBuilder(
                                  animation: _scanController,
                                  builder: (context, _) {
                                    final t = _scanController.value;
                                    final y = -0.78 + (1.56 * t);
                                    return Align(
                                      alignment: Alignment(0, y),
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 12),
                                        child: Container(
                                          height: 2.5,
                                          decoration: BoxDecoration(
                                            color: PalmTokens.primary,
                                            boxShadow: [
                                              BoxShadow(
                                                color: PalmTokens.primary
                                                    .withValues(alpha: 0.75),
                                                blurRadius: 18,
                                                spreadRadius: 1,
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                              Positioned(
                                left: 0,
                                right: 0,
                                bottom: 18,
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Center(
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 16, vertical: 10),
                                        decoration: BoxDecoration(
                                          color: Colors.black
                                              .withValues(alpha: 0.35),
                                          borderRadius:
                                              BorderRadius.circular(999),
                                          border: Border.all(
                                            color: Colors.white
                                                .withValues(alpha: 0.12),
                                          ),
                                        ),
                                        child: Text(
                                          'Align your palm within the frame',
                                          style: text.bodyMedium?.copyWith(
                                            color: Colors.white
                                                .withValues(alpha: 0.92),
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (state.isEvaluating)
                                Positioned.fill(
                                  child: Container(
                                    color: Colors.black.withValues(alpha: 0.38),
                                    child: const Center(
                                      child: CircularProgressIndicator(
                                        color: PalmTokens.primary,
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                alignment: WrapAlignment.center,
                children: [
                  _StatusPill(
                    icon: Icons.wb_sunny,
                    label: quality == null
                        ? 'Lighting'
                        : 'Lighting: ${lightingOk ? 'Good' : 'Low'}',
                    accent: lightingOk
                        ? PalmTokens.primaryDark
                        : PalmTokens.warning,
                  ),
                  _StatusPill(
                    icon: focusOk ? Icons.check_circle : Icons.blur_on,
                    label: quality == null
                        ? 'Focus'
                        : 'Focus: ${focusOk ? 'Good' : 'Low'}',
                    accent:
                        focusOk ? PalmTokens.primaryDark : PalmTokens.warning,
                  ),
                  _StatusPill(
                    icon: Icons.center_focus_strong,
                    label: quality == null ? 'Centering' : 'Centering',
                    accent:
                        centeredOk ? PalmTokens.textMain : PalmTokens.textSub,
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: _ActionCard(
                      title: 'Use Camera',
                      icon: Icons.photo_camera_outlined,
                      selected: true,
                      enabled: !state.isEvaluating,
                      onTap: _pickFromCamera,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: _ActionCard(
                      title: 'Choose Photo',
                      icon: Icons.photo_library_outlined,
                      selected: false,
                      enabled: !state.isEvaluating,
                      onTap: _pickFromGallery,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                'Ensure your hand is flat and fingers are slightly spread.\nAvoid shadows for best results.',
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: text.bodySmall?.copyWith(
                  color: PalmTokens.textSub,
                  fontWeight: FontWeight.w600,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({
    required this.icon,
    required this.label,
    required this.accent,
  });

  final IconData icon;
  final String label;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: PalmTokens.surface,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.black.withValues(alpha: 0.06)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x06000000),
            blurRadius: 8,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: accent),
          const SizedBox(width: 8),
          Text(
            label,
            style: text.labelLarge?.copyWith(
              fontWeight: FontWeight.w800,
              color: PalmTokens.textMain,
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  const _ActionCard({
    required this.title,
    required this.icon,
    required this.selected,
    required this.enabled,
    required this.onTap,
  });

  final String title;
  final IconData icon;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return InkWell(
      borderRadius: BorderRadius.circular(PalmTokens.radiusXl),
      onTap: enabled ? onTap : null,
      child: AnimatedOpacity(
        opacity: enabled ? 1 : 0.6,
        duration: const Duration(milliseconds: 150),
        child: Container(
          height: 138,
          decoration: BoxDecoration(
            color: PalmTokens.surface,
            borderRadius: BorderRadius.circular(PalmTokens.radiusXl),
            border: Border.all(
              color: selected
                  ? PalmTokens.primary.withValues(alpha: 0.45)
                  : Colors.black.withValues(alpha: 0.06),
              width: selected ? 1.4 : 1,
            ),
            boxShadow: selected ? PalmTokens.shadowSoft : PalmTokens.shadowCard,
          ),
          child: Stack(
            children: [
              if (selected)
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: PalmTokens.primary.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(PalmTokens.radiusXl),
                    ),
                  ),
                ),
              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: selected ? PalmTokens.primary : Colors.black12,
                        borderRadius: BorderRadius.circular(999),
                        boxShadow: selected ? PalmTokens.shadowCard : null,
                      ),
                      child: Icon(
                        icon,
                        color: selected
                            ? PalmTokens.neutralDark
                            : PalmTokens.textSub,
                        size: 28,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      title,
                      style: text.titleMedium?.copyWith(
                        fontWeight:
                            selected ? FontWeight.w900 : FontWeight.w800,
                        color:
                            selected ? PalmTokens.textMain : PalmTokens.textSub,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CornerMarker extends StatelessWidget {
  const _CornerMarker({required this.alignment});

  final Alignment alignment;

  @override
  Widget build(BuildContext context) {
    final isTop = alignment.y < 0;
    final isLeft = alignment.x < 0;

    return Align(
      alignment: alignment,
      child: SizedBox(
        width: 34,
        height: 34,
        child: DecoratedBox(
          decoration: BoxDecoration(
            border: Border(
              top: isTop
                  ? BorderSide(
                      color: Colors.white.withValues(alpha: 0.8), width: 4)
                  : BorderSide.none,
              bottom: !isTop
                  ? BorderSide(
                      color: Colors.white.withValues(alpha: 0.8), width: 4)
                  : BorderSide.none,
              left: isLeft
                  ? BorderSide(
                      color: Colors.white.withValues(alpha: 0.8), width: 4)
                  : BorderSide.none,
              right: !isLeft
                  ? BorderSide(
                      color: Colors.white.withValues(alpha: 0.8), width: 4)
                  : BorderSide.none,
            ),
            borderRadius: BorderRadius.only(
              topLeft:
                  isTop && isLeft ? const Radius.circular(10) : Radius.zero,
              topRight:
                  isTop && !isLeft ? const Radius.circular(10) : Radius.zero,
              bottomLeft:
                  !isTop && isLeft ? const Radius.circular(10) : Radius.zero,
              bottomRight:
                  !isTop && !isLeft ? const Radius.circular(10) : Radius.zero,
            ),
          ),
        ),
      ),
    );
  }
}

class _HandGuidePainter extends CustomPainter {
  const _HandGuidePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final baseW = 240.0;
    final baseH = 380.0;
    final scale = math.min(size.width / baseW, size.height / baseH) * 0.92;
    final dx = (size.width - (baseW * scale)) / 2.0;
    final dy = (size.height - (baseH * scale)) / 2.0;

    final transform = Matrix4.identity()
      ..translate(dx, dy)
      ..scale(scale, scale);

    final path = _handPath().transform(transform.storage);

    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.65)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    _drawDashedPath(
      canvas,
      path,
      paint,
      dashLength: 8,
      gapLength: 8,
    );
  }

  Path _handPath() {
    return Path()
      ..moveTo(120, 370)
      ..cubicTo(120, 370, 20, 340, 20, 200)
      ..lineTo(20, 100)
      ..cubicTo(20, 88.9543, 28.9543, 80, 40, 80)
      ..cubicTo(51.0457, 80, 60, 88.9543, 60, 100)
      ..lineTo(60, 180)
      ..moveTo(120, 370)
      ..cubicTo(120, 370, 220, 340, 220, 200)
      ..lineTo(220, 120)
      ..cubicTo(220, 108.954, 211.046, 100, 200, 100)
      ..cubicTo(188.954, 100, 180, 108.954, 180, 120)
      ..lineTo(180, 180)
      ..moveTo(120, 370)
      ..lineTo(120, 200)
      ..moveTo(60, 180)
      ..lineTo(60, 80)
      ..cubicTo(60, 68.9543, 68.9543, 60, 80, 60)
      ..cubicTo(91.0457, 60, 100, 68.9543, 100, 80)
      ..lineTo(100, 180)
      ..moveTo(180, 180)
      ..lineTo(180, 60)
      ..cubicTo(180, 48.9543, 171.046, 40, 160, 40)
      ..cubicTo(148.954, 40, 140, 48.9543, 140, 60)
      ..lineTo(140, 180);
  }

  void _drawDashedPath(
    Canvas canvas,
    Path path,
    Paint paint, {
    required double dashLength,
    required double gapLength,
  }) {
    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        final len = math.min(dashLength, metric.length - distance);
        final segment = metric.extractPath(distance, distance + len);
        canvas.drawPath(segment, paint);
        distance += dashLength + gapLength;
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
