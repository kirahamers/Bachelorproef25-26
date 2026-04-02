import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

class IdScannerService {
  final TextRecognizer _recognizer = TextRecognizer();

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