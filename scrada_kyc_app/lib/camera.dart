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

    int cameraIndex = 0; 
    if (widget.instructie.toLowerCase().contains("gezicht") || widget.instructie.toLowerCase().contains("selfie")) {
      cameraIndex = cameras.indexWhere((c) => c.lensDirection == CameraLensDirection.front);
      if (cameraIndex == -1) cameraIndex = 0;
    }

    _controller = CameraController(
      cameras[cameraIndex],
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

    bool isGezicht = widget.instructie.toLowerCase().contains("gezicht") || widget.instructie.toLowerCase().contains("selfie");

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text(widget.instructie), 
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
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

          ColorFiltered(
            colorFilter: ColorFilter.mode(
              Colors.black.withOpacity(0.7),
              BlendMode.srcOut,
            ),
            child: Stack(
              children: [
                Container(
                  decoration: const BoxDecoration(
                    color: Colors.black,
                    backgroundBlendMode: BlendMode.dstOut,
                  ),
                ),
                Align(
                  alignment: Alignment.center,
                  child: Container(
                    height: isGezicht ? 300 : 220,
                    width: isGezicht ? 220 : 340,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: isGezicht 
                        ? BorderRadius.all(Radius.elliptical(220, 300))
                        : BorderRadius.circular(15),
                    ),
                  ),
                ),
              ],
            ),
          ),

          //rand in camera
          Align(
            alignment: Alignment.center,
            child: Container(
              height: isGezicht ? 300 : 220,
              width: isGezicht ? 220 : 340,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.white, width: 2),
                borderRadius: isGezicht 
                        ? BorderRadius.all(Radius.elliptical(220, 300))
                        : BorderRadius.circular(15),
              ),
            ),
          ),

          //instructie
          Positioned(
            top: 40,
            left: 0,
            right: 0,
            child: Text(
              isGezicht ? "Plaats uw gezicht in het ovaal" : "Plaats de ID-kaart in het kader",
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w500),
            ),
          ),

          //knop
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