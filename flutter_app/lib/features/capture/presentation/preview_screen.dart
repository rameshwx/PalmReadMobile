import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../shared/theme/palm_tokens.dart';
import '../../upload/presentation/upload_progress_screen.dart';
import '../state/capture_controller.dart';

class PreviewScreen extends ConsumerWidget {
  const PreviewScreen({super.key});

  Future<void> _retake(BuildContext context, WidgetRef ref) async {
    final result = await showModalBottomSheet<ImageSource?>(
      context: context,
      showDragHandle: true,
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(Icons.photo_camera_outlined),
                  title: const Text('Use Camera'),
                  onTap: () => Navigator.of(ctx).pop(ImageSource.camera),
                ),
                ListTile(
                  leading: const Icon(Icons.photo_library_outlined),
                  title: const Text('Choose Photo'),
                  onTap: () => Navigator.of(ctx).pop(ImageSource.gallery),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (result == null) return;
    if (!context.mounted) return;

    final picker = ImagePicker();
    final file = await picker.pickImage(
      source: result,
      preferredCameraDevice: CameraDevice.rear,
      imageQuality: 92,
      maxWidth: 1600,
      maxHeight: 1600,
    );
    if (file == null) return;

    await ref.read(captureControllerProvider.notifier).setImage(file);
  }

  void _setHandedness(WidgetRef ref, String value) {
    ref.read(captureControllerProvider.notifier).setHandedness(value);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(captureControllerProvider);
    final file = state.imageFile;
    final quality = state.quality;
    final text = Theme.of(context).textTheme;

    if (file == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Verify Photo')),
        body: const Center(child: Text('No image selected.')),
      );
    }

    final sharp = quality?.isBlurOk ?? true;
    final badgeText = sharp ? 'Sharp' : 'Blurry';
    final likelyHand = quality?.isLikelyHand ?? true;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Verify Photo'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          IconButton(
            onPressed: () {
              showDialog<void>(
                context: context,
                builder: (_) => AlertDialog(
                  title: const Text('Why verify?'),
                  content: const Text(
                    'Verifying the photo and selecting the correct hand improves accuracy.',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('OK'),
                    ),
                  ],
                ),
              );
            },
            icon: const Icon(Icons.help_outline),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(
            height: 1,
            color: Colors.black.withValues(alpha: 0.06),
          ),
        ),
      ),
      body: Stack(
        children: [
          ListView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 140),
            children: [
              Container(
                decoration: BoxDecoration(
                  color: PalmTokens.surface,
                  borderRadius: BorderRadius.circular(PalmTokens.radiusXl),
                  border:
                      Border.all(color: Colors.black.withValues(alpha: 0.06)),
                  boxShadow: PalmTokens.shadowCard,
                ),
                padding: const EdgeInsets.all(12),
                child: Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(18),
                      child: AspectRatio(
                        aspectRatio: 3 / 4,
                        child: Image.file(file, fit: BoxFit.cover),
                      ),
                    ),
                    Positioned(
                      top: 10,
                      right: 10,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 7),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.35),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.18),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              sharp ? Icons.check_circle : Icons.error_outline,
                              size: 16,
                              color: Colors.white,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              badgeText,
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
                        color: PalmTokens.surface.withValues(alpha: 0.92),
                        borderRadius: BorderRadius.circular(999),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(999),
                          onTap: () => _retake(context, ref),
                          child: Container(
                            width: 54,
                            height: 54,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(
                                  color: Colors.black.withValues(alpha: 0.06)),
                            ),
                            child: const Icon(Icons.refresh),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (!likelyHand) ...[
                const SizedBox(height: 14),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: PalmTokens.danger.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                        color: PalmTokens.danger.withValues(alpha: 0.25)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline, color: PalmTokens.danger),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          "We couldn't detect a hand in this photo. Please retake or choose a clear palm image.",
                          style: text.bodyMedium?.copyWith(
                            color: PalmTokens.textMain,
                            fontWeight: FontWeight.w700,
                            height: 1.25,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 22),
              Row(
                children: [
                  Text(
                    'SELECT HAND',
                    style: text.labelLarge?.copyWith(
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.4,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    'Required for accuracy',
                    style: text.bodySmall?.copyWith(
                      color: PalmTokens.textSub,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _HandSegmentedControl(
                value: state.handedness,
                onChanged: (v) => _setHandedness(ref, v),
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
                  top: BorderSide(color: Colors.black.withValues(alpha: 0.06)),
                ),
              ),
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: state.isEvaluating || !likelyHand
                              ? null
                              : () {
                                  Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) =>
                                          const UploadProgressScreen(),
                                    ),
                                  );
                                },
                          icon: const Icon(Icons.auto_awesome),
                          label: const Text('Upload for Analysis'),
                          style: FilledButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 18),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(18),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
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
    final items = const [
      ('left', 'Left'),
      ('unknown', 'Unknown'),
      ('right', 'Right'),
    ];

    return Container(
      height: 56,
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: PalmTokens.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.black.withValues(alpha: 0.10)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x05000000),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          for (final (k, label) in items)
            Expanded(
              child: _Segment(
                selected: value == k,
                label: label,
                onTap: () => onChanged(k),
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
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        decoration: BoxDecoration(
          color: selected ? PalmTokens.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
          boxShadow: selected
              ? const [
                  BoxShadow(
                    color: Color(0x1A13ECA4),
                    blurRadius: 14,
                    offset: Offset(0, 6),
                  ),
                ]
              : null,
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
