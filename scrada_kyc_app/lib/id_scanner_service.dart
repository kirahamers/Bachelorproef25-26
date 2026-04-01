import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

class IdScannerService {
  final TextRecognizer _recognizer = TextRecognizer();

  //Belgische RSZV checkdigit
  int calculateIdModulo(String data) {
    List<int> weights = [7, 3, 1];
    int sum = 0;
    for (int i = 0; i < data.length; i++) {
      int code = data.codeUnitAt(i);
      int val = (code >= 48 && code <= 57) ? code - 48 : (code >= 65 && code <= 90 ? code - 55 : 0);
      sum += val * weights[i % 3];
    }
    return sum % 10;
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