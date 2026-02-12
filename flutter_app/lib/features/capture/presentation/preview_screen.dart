import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../upload/presentation/upload_progress_screen.dart';
import '../state/capture_controller.dart';

class PreviewScreen extends ConsumerWidget {
  const PreviewScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(captureControllerProvider);

    if (state.imageFile == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Preview')),
        body: const Center(child: Text('No image selected.')),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Preview & Handedness')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.file(state.imageFile!, fit: BoxFit.contain),
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: state.handedness,
              decoration: const InputDecoration(labelText: 'Handedness'),
              items: const [
                DropdownMenuItem(value: 'unknown', child: Text('Unknown')),
                DropdownMenuItem(value: 'left', child: Text('Left hand')),
                DropdownMenuItem(value: 'right', child: Text('Right hand')),
              ],
              onChanged: (value) {
                if (value != null) {
                  ref
                      .read(captureControllerProvider.notifier)
                      .setHandedness(value);
                }
              },
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                      builder: (_) => const UploadProgressScreen()),
                );
              },
              child: const Text('Upload for Analysis'),
            ),
          ],
        ),
      ),
    );
  }
}
