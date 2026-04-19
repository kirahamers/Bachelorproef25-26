import 'package:flutter/foundation.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:image/image.dart' as img;
import 'package:tflite_flutter_plus/tflite_flutter_plus.dart';

class IdScannerService {
  final TextRecognizer _recognizer = TextRecognizer();

  final FaceDetector _faceDetector = FaceDetector(
    options: FaceDetectorOptions(
      performanceMode: FaceDetectorMode.accurate,
    ),
  );

//TFLite model voor gezichtsvergelijking met gebruik van MobileFaceNet
  Interpreter? _interpreter;

  Future<void> loadModel() async {
    try {
      _interpreter = await Interpreter.fromAsset('mobilefacenet.tflite');
    } catch (e) {
      debugPrint("Fout bij laden model: $e");
    }
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

//cosine similarity
double _calculateCosineSimilarity(List<double> e1, List<double> e2) {
  double dotProduct = 0.0;
  double normA = 0.0;
  double normB = 0.0;
  for (int i = 0; i < e1.length; i++) {
    dotProduct += e1[i] * e2[i];
    normA += e1[i] * e1[i];
    normB += e2[i] * e2[i];
  }
  return dotProduct / (sqrt(normA) * sqrt(normB));
}

Future<File?> extractFace(String imagePath) async {
  final inputImage = InputImage.fromFilePath(imagePath);
  //ML Kit om gezicht te detecteren + croppen
  final List<Face> faces = await _faceDetector.processImage(inputImage);

  if (faces.isEmpty) return null;

  final face = faces.first;
  final rect = face.boundingBox;

//pixels lezen
  final bytes = await File(imagePath).readAsBytes();
  img.Image? originalImage = img.decodeImage(bytes);

  if (originalImage == null) return null;

  int padding = (rect.width * 0.05).toInt();
  
  //voor crop
  int x = (rect.left - padding).clamp(0, originalImage.width).toInt();
  int y = (rect.top - padding).clamp(0, originalImage.height).toInt();
  int w = (rect.width + padding * 2).clamp(0, originalImage.width - x).toInt();
  int h = (rect.height + padding * 2).clamp(0, originalImage.height - y).toInt();

final croppedFace = img.copyCrop(originalImage, x: x, y: y, width: w, height: h);

//voor belichting en contrast gelijk te maken met id foto
  final normalizedFace = img.adjustColor(
    croppedFace, 
    contrast: 1.2,
    brightness: 1.0, 
  );

  final tempDir = Directory.systemTemp;
  final faceFile = File('${tempDir.path}/face_id_crop_${DateTime.now().millisecondsSinceEpoch}.jpg');
  
  return await faceFile.writeAsBytes(img.encodeJpg(normalizedFace));
}

Future<double> getSimilarityScore(File faceId, File selfie) async {
  final embedding1 = await _preprocessImage(faceId);
  final embedding2 = await _preprocessImage(selfie);

  return _calculateCosineSimilarity(embedding1, embedding2);
}

  Future<List<double>> _preprocessImage(File imageFile) async {
    if (_interpreter == null) {
      await loadModel();
    }

    if (_interpreter == null) {
      throw Exception("AI model kon niet geladen worden.");
    }

    final bytes = await imageFile.readAsBytes();
    final image = img.decodeImage(bytes);

    if (image == null) return [];

//rescaling voor het model, MobileFaceNet is 112x112 input
    final resizedImage = img.copyResize(image, width: 112, height: 112);

    double sum = 0;
    //mean substraction
    for (var pixel in resizedImage) {
      sum += pixel.r + pixel.g + pixel.b;
    }
    double mean = sum / (112 * 112 * 3);

  //omzetten naar FLoat32 voor TFLite
    var input = Float32List(1 * 112 * 112 * 3);
    var buffer = Float32List.view(input.buffer);
    int pixelIndex = 0;

  for (var y = 0; y < 112; y++) {
    for (var x = 0; x < 112; x++) {
      var pixel = resizedImage.getPixel(x, y);
      //(pixelwaarde - gemiddelde) / 128
      buffer[pixelIndex++] = (pixel.r - mean) / 128.0;
      buffer[pixelIndex++] = (pixel.g - mean) / 128.0;
      buffer[pixelIndex++] = (pixel.b - mean) / 128.0;
    }
  }

  var output = List.filled(1 * 192, 0.0).reshape([1, 192]);
  _interpreter!.run(input.reshape([1, 112, 112, 3]), output);

  return List<double>.from(output[0]);
  }

//OCR met ML Kit
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