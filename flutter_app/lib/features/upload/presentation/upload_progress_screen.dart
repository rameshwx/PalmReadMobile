import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../capture/state/capture_controller.dart';
import '../../result/presentation/result_screen.dart';
import '../state/upload_controller.dart';

class UploadProgressScreen extends ConsumerStatefulWidget {
  const UploadProgressScreen({super.key});

  @override
  ConsumerState<UploadProgressScreen> createState() =>
      _UploadProgressScreenState();
}

class _UploadProgressScreenState extends ConsumerState<UploadProgressScreen> {
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) {
      return;
    }
    _started = true;

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await ref.read(uploadControllerProvider.notifier).startUpload();
      final state = ref.read(uploadControllerProvider);
      if (!mounted) {
        return;
      }

      if (state.status == 'completed' && state.readId != null) {
        final readId = state.readId!;
        ref.read(captureControllerProvider.notifier).clear();
        ref.read(uploadControllerProvider.notifier).reset();
        if (!mounted) {
          return;
        }

        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => ResultScreen(readId: readId)),
          (route) => route.isFirst,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(uploadControllerProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Uploading')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            LinearProgressIndicator(
                value: state.status == 'uploading' ? state.progress : null),
            const SizedBox(height: 16),
            Text('Status: ${state.status}'),
            if (state.readId != null) Text('Result ID: ${state.readId}'),
            if (state.lastDetail?.handSignatureHash != null)
              Text(
                  'Hand signature hash: ${state.lastDetail!.handSignatureHash}'),
            if (state.error != null) ...[
              const SizedBox(height: 12),
              Text(
                state.error!,
                style: const TextStyle(color: Colors.red),
              ),
              const SizedBox(height: 8),
              ElevatedButton(
                onPressed: () =>
                    ref.read(uploadControllerProvider.notifier).startUpload(),
                child: const Text('Retry'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
