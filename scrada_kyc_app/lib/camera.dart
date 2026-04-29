import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart'; // Nodig voor de bytes
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'dart:io';
import 'camera_ui.dart';

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
  //voor liveness
  final _faceDetector = FaceDetector(options: FaceDetectorOptions(enableClassification: true));
  
  bool _isInitializing = true;
  int _selectedCameraIndex = 0;
  FlashMode _currentFlashMode = FlashMode.off;

  bool _showInstructions = true;

  //liveness
  bool _isLive = false;
  bool _hasBlinked = false;
  bool _isProcessingFrame = false;

  @override
  void initState() {
    super.initState();
    _initCamera();
  }

  Future<void> _initCamera() async {
    final cameras = await availableCameras();
    if (cameras.isEmpty) return;

    bool isGezicht = widget.instructie.toLowerCase().contains("gezicht") || widget.instructie.toLowerCase().contains("selfie");

    int cameraIndex = 0; 
    if (isGezicht) {
      cameraIndex = cameras.indexWhere((c) => c.lensDirection == CameraLensDirection.front);
      if (cameraIndex == -1) cameraIndex = 0;
    }

    _controller = CameraController(
      cameras[cameraIndex],
      ResolutionPreset.high,
      enableAudio: false,
      //ML Kit stream
      imageFormatGroup: Platform.isAndroid ? ImageFormatGroup.nv21 : ImageFormatGroup.bgra8888,
    );

    try {
      await _controller!.initialize();
      
      if (isGezicht) {
        _controller!.startImageStream((image) => _checkLiveness(image));
      } else {
        _isLive = true;
      }
    } catch (e) {
      debugPrint("Camera error: $e");
    }
    if (mounted) setState(() => _isInitializing = false);
  }

  Future<void> _checkLiveness(CameraImage image) async {
    if (_isLive || _isProcessingFrame) return;
    _isProcessingFrame = true;

    try {
      final inputImage = _inputImageFromCameraImage(image);
      if (inputImage == null) return;

      final faces = await _faceDetector.processImage(inputImage);

      if (faces.isNotEmpty) {
        final face = faces.first;
        double eyeOpenProb = face.leftEyeOpenProbability ?? 1.0;

        if (eyeOpenProb < 0.2) {
          _hasBlinked = true;
        }
        
        if (_hasBlinked && eyeOpenProb > 0.7) {
          if (mounted) {
            setState(() {
              _isLive = true;
            });
          }
          await _controller?.stopImageStream();
        }
      }
    } catch (e) {
      debugPrint("Liveness check error: $e");
    } finally {
      _isProcessingFrame = false;
    }
  }

//verwerken van live camera naar ML Kit input
  InputImage? _inputImageFromCameraImage(CameraImage image) {
    final sensorOrientation = _controller!.description.sensorOrientation;
    final rotation = InputImageRotationValue.fromRawValue(sensorOrientation);
    if (rotation == null) return null;

    final format = InputImageFormatValue.fromRawValue(image.format.raw);
    if (format == null) return null;

    final plane = image.planes.first;

    return InputImage.fromBytes(
      bytes: plane.bytes,
      metadata: InputImageMetadata(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        rotation: rotation,
        format: format,
        bytesPerRow: plane.bytesPerRow,
      ),
    );
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
    _faceDetector.close();
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
          CameraMaskOverlay(isGezicht: isGezicht),
          CameraFocusFrame(isGezicht: isGezicht),

          // 1. De instructies overlay (met spread operator voor de list)
          if (isGezicht && _showInstructions)
            Container(
              color: Colors.black.withOpacity(0.8),
              child: Center(
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 40),
                  padding: const EdgeInsets.all(25),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.lightbulb, color: Color(0xFF8B0000), size: 40),
                      const SizedBox(height: 15),
                      const Text(
                        "INSTRUCTIES",
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black),
                      ),
                      const SizedBox(height: 20),
                      const Text("1. Zorg voor goede belichting", style: TextStyle(fontSize: 15, color: Colors.black87)),
                      const Text("2. Haal haar uit uw gezicht", style: TextStyle(fontSize: 15, color: Colors.black87)),
                      const Text("3. Kijk neutraal (niet glimlachen)", style: TextStyle(fontSize: 15, color: Colors.black87)),
                      const SizedBox(height: 25),
                      
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF8B0000),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          onPressed: () => setState(() => _showInstructions = false),
                          child: const Text("BEGREPEN"),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // 2. De Camera UI (alleen tonen als instructies weg zijn OF het is geen gezichtsscan)
          // Gebruik de spread operator '...' voor de list
          if (!isGezicht || !_showInstructions) ...[
            Positioned(
              top: 40, left: 0, right: 0,
              child: Text(
                isGezicht 
                  ? (_isLive ? "Neem nu de foto." : (_hasBlinked ? "Kijk in de camera..." : "Knipper met je ogen")) 
                  : "Plaats de ID-kaart in het kader",
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w500),
              ),
            ),

            //als live true is
            Positioned(
              bottom: 40, left: 0, right: 0,
              child: Center(
                child: FloatingActionButton.large(
                  backgroundColor: _isLive ? const Color(0xFF8B0000) : Colors.grey,
                  onPressed: _isLive ? () async {
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
                  } : null,
                  child: Icon(_isLive ? Icons.camera_alt : Icons.lock, color: Colors.white, size: 40),
                ),
              ),
            ),
          ], 
        ],
      ),
    );
  }
}