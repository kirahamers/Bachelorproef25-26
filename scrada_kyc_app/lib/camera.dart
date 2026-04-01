import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'dart:io';

class CameraScannerWidget extends StatefulWidget {
  final Function(String, String) onScanComplete; 
  final String instructie;

  const CameraScannerWidget({
    super.key, 
    required this.onScanComplete,
    required this.instructie
  });

  @override
  State<CameraScannerWidget> createState() => _CameraScannerWidgetState();
}

class _CameraScannerWidgetState extends State<CameraScannerWidget> {
  CameraController? _controller;
  final _recognizer = TextRecognizer();
  bool _isInitializing = true;
  int _selectedCameraIndex = 0;

  FlashMode _currentFlashMode = FlashMode.off;

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
      ResolutionPreset.high,
      enableAudio: false,
    );

    try {
      await _controller!.initialize();
    } catch (e) {
      debugPrint("Camera error: $e");
    }
    if (mounted) setState(() => _isInitializing = false);
  }

  Future<void> _toggleFlash() async {
    if (_controller == null) return;
    try {
      if (_currentFlashMode == FlashMode.off) {
        await _controller!.setFlashMode(FlashMode.torch);
        _currentFlashMode = FlashMode.torch;
      } else {
        await _controller!.setFlashMode(FlashMode.off);
        _currentFlashMode = FlashMode.off;
      }
      setState(() {});
    } catch (e) {
      debugPrint("Flash toggle error: $e");
    }
  }

  @override
  void dispose() {
    _controller?.setFlashMode(FlashMode.off);
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
      appBar: AppBar(title: Text(widget.instructie), 
      backgroundColor: Colors.transparent,
      actions: [
        IconButton(
          icon: Icon(_currentFlashMode == FlashMode.off ? Icons.flash_off : Icons.flash_on, color: Colors.white),
          onPressed: _toggleFlash,
        ),
      ],
      ),
      body: Stack(
        children: [
          Center(child: CameraPreview(_controller!)),
          Center(
            child: Container(
              width: 320,
              height: 200,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.red, width: 3),
                borderRadius: BorderRadius.circular(15),
              ),
            ),
          ),
          Positioned(
            bottom: 40, left: 0, right: 0,
            child: Center(
              child: FloatingActionButton.large(
                backgroundColor: const Color(0xFF8B0000),
                onPressed: () async {
                  if (_controller!.value.isTakingPicture) return;
                  try {
                    final img = await _controller!.takePicture();
                    
                    final inputImage = InputImage.fromFilePath(img.path);
                    final recognized = await _recognizer.processImage(inputImage);
                    
                    widget.onScanComplete(recognized.text, img.path);
                    if (mounted) Navigator.pop(context);
                  } catch (e) {
                    debugPrint("Error: $e");
                  }
                },
                child: const Icon(Icons.camera_alt, color: Colors.white, size: 40),
              ),
            ),
          ),
        ],
      ),
    );
  }
}