import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

class CameraScannerWidget extends StatefulWidget {
  final Function(String) onTextDetected;
  const CameraScannerWidget({super.key, required this.onTextDetected});

  @override
  State<CameraScannerWidget> createState() => _CameraScannerWidgetState();
}

class _CameraScannerWidgetState extends State<CameraScannerWidget> {
  CameraController? _controller;
  final _recognizer = TextRecognizer();
  bool _isInitializing = true;
  int _selectedCameraIndex = 0;

  @override
  void initState() {
    super.initState();
    _initCamera();
  }

  Future<void> _initCamera() async {
    final cameras = await availableCameras();
    if (cameras.isEmpty) return;

    _controller = CameraController(
      cameras[_selectedCameraIndex],
      ResolutionPreset.medium,
      enableAudio: false,
    );

    try {
      await _controller!.initialize();
    } catch (e) {
      debugPrint("Camera error: $e");
    }
    if (mounted) setState(() => _isInitializing = false);
  }

  Future<void> _toggleCamera() async {
    final cameras = await availableCameras();
    if (cameras.length < 2) return;

    _selectedCameraIndex = (_selectedCameraIndex + 1) % cameras.length;
    await _controller?.dispose();
    _initCamera();
  }

  @override
  void dispose() {
    _controller?.dispose();
    _recognizer.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isInitializing || _controller == null || !_controller!.value.isInitialized) {
      return const Scaffold(backgroundColor: Colors.black, body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Center(child: CameraPreview(_controller!)),
          Center(
            child: Container(
              width: 300, height: 200,
              decoration: BoxDecoration(border: Border.all(color: Colors.white, width: 2), borderRadius: BorderRadius.circular(12)),
            ),
          ),
          Positioned(
            bottom: 40, left: 0, right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                IconButton(
                  icon: const Icon(Icons.flip_camera_ios, color: Colors.white, size: 35),
                  onPressed: _toggleCamera,
                ),
                FloatingActionButton.large(
                  backgroundColor: const Color(0xFF8B0000),
                  onPressed: () async {
                    if (_controller!.value.isTakingPicture) return;
                    try {
                      final img = await _controller!.takePicture();
                      final inputImage = InputImage.fromFilePath(img.path);
                      final recognized = await _recognizer.processImage(inputImage);
                      
                      widget.onTextDetected(recognized.text);
                      if (mounted) Navigator.pop(context);
                    } catch (e) {
                      debugPrint("Error: $e");
                    }
                  },
                  child: const Icon(Icons.camera_alt, color: Colors.white),
                ),
                const SizedBox(width: 48), 
              ],
            ),
          ),
        ],
      ),
    );
  }
}