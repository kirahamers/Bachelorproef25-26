import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:pdfx/pdfx.dart';
import 'package:path_provider/path_provider.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'camera.dart'; 

class KycScreen extends StatefulWidget {
  const KycScreen({super.key});

  @override
  State<KycScreen> createState() => _KycScreenState();
}

class _KycScreenState extends State<KycScreen> {
  final TextEditingController _kboController = TextEditingController();
  final TextEditingController _idScanController = TextEditingController();
  final TextEditingController _datumController = TextEditingController();
  
  final TextRecognizer _recognizer = TextRecognizer();

  Map<String, dynamic>? _bedrijfsData;
  String _matchResultaat = "";
  bool _isLoading = false;

  @override
  void dispose() {
    _recognizer.close();
    super.dispose();
  }

  void _verwerkScanData(String ruweTekst) {
    String schoneTekst = ruweTekst.toLowerCase();
    
    bool isBelgian = schoneTekst.contains("belgie") || 
                     schoneTekst.contains("belgique") || 
                     schoneTekst.contains("identiteitskaart");
                     
    if (!isBelgian) {
      _showError("Geen geldige Belgische eID herkend. Probeer een scherpere foto.");
      return;
    }

    String gevondenNaam = "NIET GEVONDEN";
    String gevondenDatum = "NIET GEVONDEN";

    List<String> lijnen = ruweTekst.split('\n');
    RegExp datumRegEx = RegExp(r"(\d{2}[\s.-]\d{2}[\s.-]\d{4})");

    for (int i = 0; i < lijnen.length; i++) {
      String lijn = lijnen[i].toLowerCase();

      if ((lijn.contains("naam") || lijn.contains("nom")) && i + 1 < lijnen.length) {
        String naam = lijnen[i + 1].trim();
        if (!naam.toLowerCase().contains("belgi")) {
          gevondenNaam = naam.toUpperCase();
        }
      }

      //TODO: niet gevonden
      if (lijn.contains("tot") || lijn.contains("au") || lijn.contains("valide")) {
        String tekstBlok = lijn + " " + (i + 1 < lijnen.length ? lijnen[i+1].toLowerCase() : "");
        Match? match = datumRegEx.firstMatch(tekstBlok);
        if (match != null) gevondenDatum = match.group(0)!;
      }
    }

    setState(() {
      _idScanController.text = gevondenNaam;
      _datumController.text = gevondenDatum;
    });

    _checkVervaldatum(gevondenDatum);
  }

  void _checkVervaldatum(String datumStr) {
    try {
      List<String> parts = datumStr.split(RegExp(r'[.\s-]'));
      DateTime verval = DateTime(int.parse(parts[2]), int.parse(parts[1]), int.parse(parts[0]));
      if (verval.isBefore(DateTime.now())) {
        _showError("WAARSCHUWING: Deze kaart is vervallen op $datumStr!");
      }
    } catch (_) {}
  }

  Future<void> _pickAndScanFile() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['jpg', 'png', 'pdf', 'jpeg'],
    );

    if (result != null && result.files.single.path != null) {
      String filePath = result.files.single.path!;
      String rawText = "";

      try {
        if (filePath.toLowerCase().endsWith('.pdf')) {
          final document = await PdfDocument.openFile(filePath);
          final page = await document.getPage(1);
          final pageImage = await page.render(width: page.width * 2, height: page.height * 2);
          
          final tempDir = await getTemporaryDirectory();
          final tempFile = File('${tempDir.path}/pdf_temp_image.png');
          await tempFile.writeAsBytes(pageImage!.bytes);
          
          final inputImage = InputImage.fromFilePath(tempFile.path);
          final recognized = await _recognizer.processImage(inputImage);
          rawText = recognized.text;
          
          await page.close();
          await document.close();
        } else {
          //TODO dit wegdoen
          final inputImage = InputImage.fromFilePath(filePath);
          final recognized = await _recognizer.processImage(inputImage);
          rawText = recognized.text;
        }
        _verwerkScanData(rawText);
      } catch (e) {
        _showError("Fout bij verwerken bestand: $e");
      }
    }
  }

  Future<void> _voerKycUit() async {
    setState(() { _isLoading = true; _bedrijfsData = null; _matchResultaat = ""; });
    try {
      final nummer = _kboController.text.replaceAll('.', '').replaceAll(' ', '');
      final url = Uri.parse('http://10.0.2.2:5012/api/kyc/$nummer');
      final response = await http.get(url).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        setState(() => _bedrijfsData = json.decode(response.body));
      } else {
        _showError("Onderneming niet gevonden.");
      }
    } catch (e) {
      _showError("Backend onbereikbaar: $e");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _verifieerEID() {
    if (_bedrijfsData == null) return;
    final gescandeNaam = _idScanController.text.trim().toUpperCase();
    
    if (gescandeNaam == "NIET GEVONDEN" || gescandeNaam.isEmpty) {
      _showError("Scan of upload eerst een geldig identiteitsbewijs.");
      return;
    }

    List<String> bestuurders = List<String>.from(_bedrijfsData!['directors']);
    bool isBestuurder = bestuurders.any((b) => 
      b.toUpperCase().contains(gescandeNaam) || gescandeNaam.contains(b.toUpperCase())
    );

    setState(() {
      _matchResultaat = isBestuurder 
          ? "IDENTITEIT BEVESTIGD \nBevoegde bestuurder gevonden." 
          : "TOEGANG GEWEIGERD \nDeze persoon is geen bestuurder volgens de KBO.";
    });
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), duration: const Duration(seconds: 4)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Scrada KYC Portaal"), backgroundColor: const Color(0xFF8B0000), foregroundColor: Colors.white),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            _buildCard("1. KBO Bedrijfscheck", Icons.business, [
              TextField(controller: _kboController, decoration: const InputDecoration(labelText: "Ondernemingsnummer (bijv. 0400.378.485)")),
              const SizedBox(height: 10),
              ElevatedButton(
                onPressed: _isLoading ? null : _voerKycUit,
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF8B0000), foregroundColor: Colors.white),
                child: _isLoading ? const CircularProgressIndicator(color: Colors.white) : const Text("RAADPLEEG KBO"),
              ),
            ]),
            if (_bedrijfsData != null) ...[
              _buildBedrijfsInfo(),
              _buildCard("2. Identiteitscontrole", Icons.badge, [
                TextField(controller: _idScanController, decoration: const InputDecoration(labelText: "Gescande Naam")),
                TextField(controller: _datumController, decoration: const InputDecoration(labelText: "Vervaldatum eID")),
                const SizedBox(height: 15),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    ElevatedButton.icon(
                      onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (c) => CameraScannerWidget(onTextDetected: _verwerkScanData))),
                      icon: const Icon(Icons.camera_alt),
                      label: const Text("SCAN"),
                    ),
                    ElevatedButton.icon(
                      onPressed: _pickAndScanFile,
                      icon: const Icon(Icons.upload_file),
                      label: const Text("PDF / FOTO"),
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.blueGrey, foregroundColor: Colors.white),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.black87, foregroundColor: Colors.white),
                    onPressed: _verifieerEID, 
                    child: const Text("VERIFIEER BESTUURDER")
                  ),
                ),
                if (_matchResultaat.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  Text(_matchResultaat, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                ]
              ]),
            ]
          ],
        ),
      ),
    );
  }

  Widget _buildCard(String title, IconData icon, List<Widget> children) {
    return Card(child: Padding(padding: const EdgeInsets.all(15), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [Row(children: [Icon(icon, color: const Color(0xFF8B0000)), const SizedBox(width: 10), Text(title, style: const TextStyle(fontWeight: FontWeight.bold))]), const Divider(), ...children])));
  }

  Widget _buildBedrijfsInfo() {
    return Card(color: Colors.green.shade50, child: ListTile(title: Text(_bedrijfsData!['name'], style: const TextStyle(fontWeight: FontWeight.bold)), subtitle: Text("Gekende Bestuurders: ${_bedrijfsData!['directors'].join(', ')}")));
  }
}