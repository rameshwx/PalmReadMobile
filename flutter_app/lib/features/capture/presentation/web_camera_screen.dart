import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../shared/theme/palm_tokens.dart';

/// A live browser camera flow for Flutter Web.
///
/// `image_picker` can only hint to a browser file input that the camera is
/// preferred. Desktop browsers commonly ignore that hint, so web uses the
/// camera plugin's getUserMedia-backed preview instead.
class WebCameraScreen extends StatefulWidget {
  const WebCameraScreen({super.key});

  @override
  State<WebCameraScreen> createState() => _WebCameraScreenState();
}

class _WebCameraScreenState extends State<WebCameraScreen> {
  CameraController? _controller;
  String? _error;
  bool _initializing = true;
  bool _capturing = false;

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _initializeCamera() async {
    CameraController? controller;
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        throw StateError('No camera was found in this browser.');
      }

      final camera = cameras.firstWhere(
        (item) => item.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );
      controller = CameraController(
        camera,
        ResolutionPreset.high,
        enableAudio: false,
      );
      await controller.initialize();

      if (!mounted) {
        await controller.dispose();
        return;
      }

      setState(() {
        _controller = controller;
        _initializing = false;
      });
    } on CameraException catch (error) {
      await controller?.dispose();
      _showError(_cameraErrorMessage(error));
    } catch (_) {
      await controller?.dispose();
      _showError(
        'We could not access your camera. Check the browser permission, or choose a photo instead.',
      );
    }
  }

  String _cameraErrorMessage(CameraException error) {
    switch (error.code) {
      case 'CameraAccessDenied':
      case 'CameraAccessDeniedWithoutPrompt':
        return 'Camera permission was denied. Allow camera access in your browser, or choose a photo instead.';
      case 'CameraAccessRestricted':
        return 'Camera access is restricted on this device. Choose a photo instead.';
      default:
        return 'We could not access your camera. Check the browser permission, or choose a photo instead.';
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    setState(() {
      _error = message;
      _initializing = false;
    });
  }

  Future<void> _choosePhoto() async {
    final file = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 92,
      maxWidth: 1600,
      maxHeight: 1600,
    );
    if (!mounted || file == null) return;
    Navigator.of(context).pop(file);
  }

  Future<void> _takePicture() async {
    final controller = _controller;
    if (_capturing || controller == null || !controller.value.isInitialized) {
      return;
    }

    setState(() => _capturing = true);
    try {
      final file = await controller.takePicture();
      if (!mounted) return;
      Navigator.of(context).pop(file);
    } on CameraException catch (error) {
      _showError(_cameraErrorMessage(error));
      if (mounted) setState(() => _capturing = false);
    } catch (_) {
      _showError('We could not take that picture. Please try again.');
      if (mounted) setState(() => _capturing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    final canCapture = !_initializing &&
        _error == null &&
        controller != null &&
        controller.value.isInitialized;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Take Palm Photo'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 520),
                  child: AspectRatio(
                    aspectRatio: 3 / 4,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(PalmTokens.radiusXl),
                      child: _buildPreview(controller, canCapture),
                    ),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
              child: Column(
                children: [
                  if (_error != null) ...[
                    Text(
                      _error!,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: PalmTokens.textMain,
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    const SizedBox(height: 12),
                  ] else
                    const Text(
                      'Keep your palm flat, centered, and well lit.',
                      textAlign: TextAlign.center,
                    ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _choosePhoto,
                          icon: const Icon(Icons.photo_library_outlined),
                          label: const Text('Choose Photo'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: canCapture ? _takePicture : null,
                          icon: _capturing
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(Icons.camera_alt_outlined),
                          label: const Text('Capture'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPreview(CameraController? controller, bool canCapture) {
    if (_initializing) {
      return const ColoredBox(
        color: Colors.black,
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (!canCapture || controller == null) {
      return const ColoredBox(
        color: Color(0xFF101516),
        child: Center(child: Icon(Icons.no_photography_outlined, size: 56)),
      );
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        CameraPreview(controller),
        IgnorePointer(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: CustomPaint(painter: _CameraGuidePainter()),
          ),
        ),
      ],
    );
  }
}

class _CameraGuidePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.75)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    final rect = RRect.fromRectAndRadius(
      Offset.zero & size,
      const Radius.circular(28),
    );
    canvas.drawRRect(rect, paint);
  }

  @override
  bool shouldRepaint(covariant _CameraGuidePainter oldDelegate) => false;
}
