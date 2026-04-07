import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:image/image.dart' as img;
import 'package:tflite_flutter/tflite_flutter.dart';

class IdScannerService {
  final TextRecognizer _recognizer = TextRecognizer();

  final FaceDetector _faceDetector = FaceDetector(
    options: FaceDetectorOptions(
      performanceMode: FaceDetectorMode.accurate,
    ),
  );

  Interpreter? _interpreter;

  Future<void> loadModel() async {
    _interpreter = await Interpreter.fromAsset('assets/mobile_facenet.tflite');
  }

//overgenomen van https://sandervandevelde.wordpress.com/2020/08/13/belgische-rijksregisternummer-checksum-testen-dutch/
bool checkBelgianRrn(String rrn) {
  try {
    int kaartChecksum = int.parse(rrn.substring(9, 11));

    String partToCalculate = rrn.substring(0, 9);
    int rrnInt = int.parse(partToCalculate);

    int berekendeChecksum = 97 - (rrnInt % 97);

    if (kaartChecksum == berekendeChecksum) {
      return true;
    }

    int rrnInt2000 = int.parse("2$partToCalculate");
    int berekendeChecksum2000 = 97 - (rrnInt2000 % 97);

    return kaartChecksum == berekendeChecksum2000;
  } catch (e) {
    return false;
  }
}

Future<File?> extractFace(String imagePath) async {
    final inputImage = InputImage.fromFilePath(imagePath);
    final List<Face> faces = await _faceDetector.processImage(inputImage);

    if (faces.isEmpty) return null;

    final face = faces.first;
    final rect = face.boundingBox;

    final bytes = await File(imagePath).readAsBytes();
    final originalImage = img.decodeImage(bytes);

    if (originalImage == null) return null;

    //croppen adhv coordinaten van face detection
    final croppedFace = img.copyCrop(
      originalImage,
      x: rect.left.toInt(),
      y: rect.top.toInt(),
      width: rect.width.toInt(),
      height: rect.height.toInt(),
    );


    final tempDir = Directory.systemTemp;
    final faceFile = File('${tempDir.path}/face_id_crop.jpg');
    return await faceFile.writeAsBytes(img.encodeJpg(croppedFace));
  }

  //embedding van de foto berekenen adhv tflite model
  Future<List<double>> _preprocessImage(File imageFile) async {
    final bytes = await imageFile.readAsBytes();
    final image = img.decodeImage(bytes);

    if (image == null) return [];

    final resizedImage = img.copyResize(image, width: 112, height: 112);

    //pixels normaliseren naar waarden tussen -1 en 1 (verwijzing naar ml classification)
    var input = Float32List(1 * 112 * 112 * 3);
    var buffer = Float32List.view(input.buffer);
    int pixelIndex = 0;
    for (var y = 0; y < 112; y++) {
      for (var x = 0; x < 112; x++) {
        var pixel = resizedImage.getPixel(x, y);
        buffer[pixelIndex++] = (pixel.r - 128) / 128.0;
        buffer[pixelIndex++] = (pixel.g - 128) / 128.0;
        buffer[pixelIndex++] = (pixel.b - 128) / 128.0;
      }
    }

    //model uitvoeren
    var output = List.filled(1 * 192, 0.0).reshape([1, 192]);
    _interpreter!.run(input.reshape([1, 112, 112, 3]), output);

    return List<double>.from(output[0]);
  }

  Future<double> getSimilarityScore(File faceId, File selfie) async {
    final embedding1 = await _preprocessImage(faceId);
    final embedding2 = await _preprocessImage(selfie);

    //euclidian distance
    double distance = 0;
    for (int i = 0; i < embedding1.length; i++) {
      distance += pow((embedding1[i] - embedding2[i]), 2);
    }
    return sqrt(distance);
  }

  Future<String> getRecognizedText(String path) async {
    final inputImage = InputImage.fromFilePath(path);
    final RecognizedText recognizedText = await _recognizer.processImage(inputImage);
    return recognizedText.text;
  }

  void checkVervaldatum(String datumStr, Function(String) onError) {
    try {
      List<String> parts = datumStr.split(RegExp(r'[.\s-]'));
      DateTime verval = DateTime(int.parse(parts[2]), int.parse(parts[1]), int.parse(parts[0]));
      if (verval.isBefore(DateTime.now())) {
        onError("Deze kaart is vervallen op $datumStr.");
      }
    } catch (_) {}
  }

  void dispose() {
    _recognizer.close();
  }
}