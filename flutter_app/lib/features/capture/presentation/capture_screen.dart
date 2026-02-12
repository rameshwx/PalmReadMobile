import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../state/capture_controller.dart';
import 'preview_screen.dart';

class CaptureScreen extends ConsumerWidget {
  const CaptureScreen({super.key});

  Future<void> _pickImage(
      BuildContext context, WidgetRef ref, ImageSource source) async {
    final picker = ImagePicker();
    final file = await picker.pickImage(
      source: source,
      preferredCameraDevice: CameraDevice.rear,
      imageQuality: 92,
      maxWidth: 1600,
      maxHeight: 1600,
    );

    if (file == null) {
      return;
    }

    await ref.read(captureControllerProvider.notifier).setImage(file);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(captureControllerProvider);
    final quality = state.quality;
    final isEvaluating = state.isEvaluating;

    return Scaffold(
      appBar: AppBar(title: const Text('Capture Palm')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Guidance: good lighting, avoid blur, keep palm centered and filling most of frame.',
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: isEvaluating
                      ? null
                      : () => _pickImage(context, ref, ImageSource.camera),
                  child: const Text('Use Camera'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton(
                  onPressed: isEvaluating
                      ? null
                      : () => _pickImage(context, ref, ImageSource.gallery),
                  child: const Text('Choose Photo'),
                ),
              ),
            ],
          ),
          if (isEvaluating) ...[
            const SizedBox(height: 12),
            const LinearProgressIndicator(),
            const SizedBox(height: 8),
            const Text('Analyzing photo quality...'),
          ],
          const SizedBox(height: 16),
          if (state.imageFile != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.file(
                state.imageFile!,
                fit: BoxFit.cover,
                height: 260,
              ),
            ),
          const SizedBox(height: 16),
          if (quality != null)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Brightness: ${quality.brightness.toStringAsFixed(1)} '
                        '(${quality.isBrightnessOk ? 'OK' : 'Retake'})'),
                    Text(
                        'Blur variance: ${quality.blurVariance.toStringAsFixed(1)} '
                        '(${quality.isBlurOk ? 'OK' : 'Too blurry'})'),
                    Text(
                        'Palm size: ${(quality.palmCoverage * 100).toStringAsFixed(1)}% '
                        '(${quality.isPalmSizeOk ? 'Good framing' : 'Move hand closer/farther'})'),
                    Text(
                        'Centered: offset ${quality.centerOffset.toStringAsFixed(2)} '
                        '(${quality.isCentered ? 'Centered' : 'Recenter palm'})'),
                    const SizedBox(height: 8),
                    Text(
                      quality.passesHardGates
                          ? 'Quality gates passed. You can continue.'
                          : 'Quality failed. Please retake with better lighting/focus.',
                      style: TextStyle(
                        color: quality.passesHardGates
                            ? Colors.green[700]
                            : Colors.red[700],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: state.imageFile != null &&
                    (quality?.passesHardGates ?? false)
                ? () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const PreviewScreen()),
                    );
                  }
                : null,
            child: const Text('Continue to Preview'),
          ),
        ],
      ),
    );
  }
}
