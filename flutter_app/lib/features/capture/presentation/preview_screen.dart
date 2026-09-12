import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../shared/theme/palm_tokens.dart';
import '../../../shared/widgets/responsive_page.dart';
import '../../upload/presentation/upload_progress_screen.dart';
import '../state/capture_controller.dart';
import 'web_camera_screen.dart';

class PreviewScreen extends ConsumerWidget {
  const PreviewScreen({super.key});

  Future<void> _retake(BuildContext context, WidgetRef ref) async {
    final result = await showPalmSheet<ImageSource?>(
      context: context,
      builder: (ctx) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Choose a new photo',
            style: Theme.of(ctx)
                .textTheme
                .titleLarge
                ?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 4),
          Text(
            'Use a clear, well-lit palm image for the most reliable result.',
            style: Theme.of(ctx).textTheme.bodyMedium?.copyWith(
                  color: PalmTokens.textSub,
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: 14),
          PalmModalOption(
            icon: Icons.photo_camera_outlined,
            title: 'Use Camera',
            subtitle: 'Take a new palm photo',
            onTap: () => Navigator.of(ctx).pop(ImageSource.camera),
          ),
          const SizedBox(height: 4),
          PalmModalOption(
            icon: Icons.photo_library_outlined,
            title: 'Choose Photo',
            subtitle: 'Select an image from your device',
            onTap: () => Navigator.of(ctx).pop(ImageSource.gallery),
          ),
        ],
      ),
    );

    if (result == null || !context.mounted) return;

    final XFile? file;
    if (kIsWeb && result == ImageSource.camera) {
      file = await Navigator.of(context).push<XFile>(
        MaterialPageRoute(builder: (_) => const WebCameraScreen()),
      );
    } else {
      final picker = ImagePicker();
      file = await picker.pickImage(
        source: result,
        preferredCameraDevice: CameraDevice.rear,
        imageQuality: 92,
        maxWidth: 1600,
        maxHeight: 1600,
      );
    }
    if (file == null) return;

    await ref.read(captureControllerProvider.notifier).setImage(file);
  }

  Future<void> _upload(BuildContext context) async {
    final error = await Navigator.of(context).push<String?>(
      MaterialPageRoute(builder: (_) => const UploadProgressScreen()),
    );
    if (!context.mounted || error == null || error.isEmpty) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
  }

  Widget _header(BuildContext context, TextTheme text) {
    return Row(
      children: [
        IconButton(
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.arrow_back),
          tooltip: 'Back',
        ),
        Expanded(
          child: Column(
            children: [
              Text(
                'Verify Photo',
                style: text.titleLarge?.copyWith(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 4),
              Text(
                'FINAL CHECKS',
                style: text.labelSmall?.copyWith(
                  color: PalmTokens.primaryDark,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.3,
                ),
              ),
            ],
          ),
        ),
        IconButton(
          onPressed: () {
            showPalmSheet<void>(
              context: context,
              builder: (ctx) => Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Why verify?',
                    style: Theme.of(ctx)
                        .textTheme
                        .titleLarge
                        ?.copyWith(fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Photo checks and hand detection happen before upload. Selecting the correct hand improves reading accuracy.',
                    style: Theme.of(ctx).textTheme.bodyMedium?.copyWith(
                          color: PalmTokens.textSub,
                          fontWeight: FontWeight.w600,
                          height: 1.4,
                        ),
                  ),
                  const SizedBox(height: 16),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () => Navigator.of(ctx).pop(),
                      child: const Text('Got it'),
                    ),
                  ),
                ],
              ),
            );
          },
          icon: const Icon(Icons.help_outline),
          tooltip: 'Photo verification help',
        ),
      ],
    );
  }

  Widget _photoCard(
    BuildContext context,
    WidgetRef ref,
    CaptureState state,
    TextTheme text,
  ) {
    final bytes = state.imageBytes!;
    final quality = state.quality;
    final checking = state.isEvaluating || quality == null;
    final sharp = quality?.isBlurOk == true;
    final badge = checking ? 'Checking' : (sharp ? 'Sharp' : 'Needs focus');

    return PalmSurface(
      padding: const EdgeInsets.all(10),
      radius: PalmTokens.radiusXl,
      child: Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: AspectRatio(
              aspectRatio: 3 / 4,
              child: Image.memory(bytes, fit: BoxFit.cover),
            ),
          ),
          Positioned(
            top: 10,
            right: 10,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.40),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    checking
                        ? Icons.hourglass_top
                        : (sharp ? Icons.check_circle : Icons.error_outline),
                    size: 16,
                    color: Colors.white,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    badge,
                    style: text.labelLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            bottom: 10,
            right: 10,
            child: Material(
              color: PalmTokens.surface.withValues(alpha: 0.94),
              borderRadius: BorderRadius.circular(999),
              child: InkWell(
                borderRadius: BorderRadius.circular(999),
                onTap: () => _retake(context, ref),
                child: const SizedBox(
                  width: 54,
                  height: 54,
                  child: Icon(Icons.refresh),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _validationCard(CaptureState state) {
    if (state.handDetected == false) {
      return _ValidationNotice(
        icon: Icons.error_outline,
        color: PalmTokens.danger,
        message:
            "We couldn't detect a hand in this photo. Please retake or choose a clear palm image.",
      );
    }
    if (state.handDetected == true) {
      return _ValidationNotice(
        icon: Icons.check_circle_outline,
        color: PalmTokens.primaryDark,
        message: 'Hand detected. Your photo is ready for analysis.',
      );
    }
    return const SizedBox.shrink();
  }

  Widget _controls(
    BuildContext context,
    WidgetRef ref,
    CaptureState state,
    TextTheme text,
    bool desktop,
  ) {
    final canUpload = !state.isEvaluating && state.handDetected != false;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _validationCard(state),
        if (state.handDetected != null) const SizedBox(height: 18),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: Text(
                'SELECT HAND',
                style: text.labelLarge?.copyWith(
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.4,
                ),
              ),
            ),
            Flexible(
              child: Text(
                'Required for accuracy',
                textAlign: TextAlign.end,
                style: text.bodySmall?.copyWith(
                  color: PalmTokens.textSub,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _HandSegmentedControl(
          value: state.handedness,
          onChanged: ref.read(captureControllerProvider.notifier).setHandedness,
        ),
        const SizedBox(height: 14),
        Text(
          'The dominant hand represents your conscious self, while the non-dominant hand shows potential.',
          textAlign: TextAlign.center,
          style: text.bodySmall?.copyWith(
            color: PalmTokens.textSub,
            fontWeight: FontWeight.w600,
            height: 1.35,
          ),
        ),
        if (desktop) ...[
          const SizedBox(height: 24),
          _UploadButton(enabled: canUpload, onPressed: () => _upload(context)),
          const SizedBox(height: 8),
          TextButton(
            onPressed: () => _retake(context, ref),
            child: Text(
              'Retake Photo',
              style: text.titleSmall?.copyWith(
                fontWeight: FontWeight.w800,
                color: PalmTokens.textSub,
              ),
            ),
          ),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(captureControllerProvider);
    final text = Theme.of(context).textTheme;
    final image = state.imageBytes;

    if (image == null) {
      return Scaffold(
        body: Center(
          child: PalmSurface(
            child: Text(
              'No image selected.',
              style: text.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      body: SafeArea(
        child: PalmPageContainer(
          maxWidth: 1240,
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 18),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final desktop = constraints.maxWidth >= 1024;
              final header = _header(context, text);
              final photo = _photoCard(context, ref, state, text);
              final controls = _controls(context, ref, state, text, desktop);

              if (desktop) {
                final photoWidth = math.min(500.0, constraints.maxWidth * 0.46);
                return Column(
                  children: [
                    header,
                    const SizedBox(height: 20),
                    Expanded(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(width: photoWidth, child: photo),
                          const SizedBox(width: 48),
                          Expanded(
                            child: SingleChildScrollView(child: controls),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              }

              return Stack(
                children: [
                  ListView(
                    padding: const EdgeInsets.only(bottom: 138),
                    children: [
                      header,
                      const SizedBox(height: 14),
                      photo,
                      const SizedBox(height: 20),
                      controls,
                    ],
                  ),
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: PalmTokens.surface,
                        border: Border(
                          top: BorderSide(
                            color: Colors.black.withValues(alpha: 0.06),
                          ),
                        ),
                      ),
                      child: SafeArea(
                        top: false,
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(0, 14, 0, 10),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _UploadButton(
                                enabled: !state.isEvaluating &&
                                    state.handDetected != false,
                                onPressed: () => _upload(context),
                              ),
                              TextButton(
                                onPressed: () => _retake(context, ref),
                                child: Text(
                                  'Retake Photo',
                                  style: text.titleSmall?.copyWith(
                                    fontWeight: FontWeight.w800,
                                    color: PalmTokens.textSub,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _ValidationNotice extends StatelessWidget {
  const _ValidationNotice({
    required this.icon,
    required this.color,
    required this.message,
  });

  final IconData icon;
  final Color color;
  final String message;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final isError = color == PalmTokens.danger;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: isError ? 0.10 : 0.10),
        borderRadius: BorderRadius.circular(PalmTokens.radiusMd),
        border: Border.all(color: color.withValues(alpha: 0.24)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: text.bodyMedium?.copyWith(
                color: PalmTokens.textMain,
                fontWeight: FontWeight.w700,
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _UploadButton extends StatelessWidget {
  const _UploadButton({required this.enabled, required this.onPressed});

  final bool enabled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: FilledButton.icon(
        onPressed: enabled ? onPressed : null,
        icon: const Icon(Icons.auto_awesome),
        label: const Text('Upload for Analysis'),
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 18),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(PalmTokens.radiusMd),
          ),
        ),
      ),
    );
  }
}

class _HandSegmentedControl extends StatelessWidget {
  const _HandSegmentedControl({required this.value, required this.onChanged});

  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    const items = [
      ('left', 'Left'),
      ('unknown', 'Unknown'),
      ('right', 'Right'),
    ];

    return Container(
      height: 58,
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: PalmTokens.surface,
        borderRadius: BorderRadius.circular(PalmTokens.radiusMd),
        border: Border.all(color: Colors.black.withValues(alpha: 0.10)),
      ),
      child: Row(
        children: [
          for (final (key, label) in items)
            Expanded(
              child: _Segment(
                selected: value == key,
                label: label,
                onTap: () => onChanged(key),
                textStyle: text,
              ),
            ),
        ],
      ),
    );
  }
}

class _Segment extends StatelessWidget {
  const _Segment({
    required this.selected,
    required this.label,
    required this.onTap,
    required this.textStyle,
  });

  final bool selected;
  final String label;
  final VoidCallback onTap;
  final TextTheme textStyle;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        decoration: BoxDecoration(
          color: selected ? PalmTokens.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          boxShadow: selected ? PalmTokens.shadowSoft : null,
        ),
        child: Center(
          child: Text(
            label,
            style: textStyle.titleSmall?.copyWith(
              fontWeight: FontWeight.w900,
              color: selected ? PalmTokens.textMain : PalmTokens.textSub,
            ),
          ),
        ),
      ),
    );
  }
}
