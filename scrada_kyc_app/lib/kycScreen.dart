import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'camera.dart'; 
import 'id_scanner_service.dart';
import 'kycScreen_ui.dart';

class KycScreen extends StatefulWidget {
  const KycScreen({super.key});

  @override
  State<KycScreen> createState() => _KycScreenState();
}

class _KycScreenState extends State<KycScreen> {
  final TextEditingController _kboController = TextEditingController();
  final TextEditingController _idScanController = TextEditingController();
  final TextEditingController _datumController = TextEditingController();
  
  final IdScannerService _idService = IdScannerService();
  final ImagePicker _picker = ImagePicker();

  Map<String, dynamic>? _bedrijfsData;
  String _matchResultaat = "";
  bool _isLoading = false;
  String? _frontPath;
  String? _backPath;
  File? _liveSelfieFile;
  double? _faceMatchScore;
  File? _face;

@override
  void initState() {
    super.initState();
    _idService.loadModel().then((_) {
      debugPrint("AI Model succesvol geladen.");
    }).catchError((e) {
      debugPrint("Fout bij laden AI model: $e");
    });
  }

  @override
  void dispose() {
    _idService.dispose();
    _kboController.dispose();
    _idScanController.dispose();
    _datumController.dispose();
    super.dispose();
  }

void _processScannedData(String text, String path, bool isFront) {
    setState(() {
      if (isFront) _frontPath = path; else _backPath = path;
    });

    //voor checksum
    String clean = text.replaceAll(' ', '').replaceAll('\n', '').toUpperCase();
    
if (clean.contains("IDBEL")) {
    try {

      int belIndex = clean.lastIndexOf("BEL"); 
      
      if (belIndex != -1 && clean.substring(belIndex).length >= 14) {
        
        String rrnReeks = fixOcrErrors(clean.substring(belIndex + 3, belIndex + 14));

        bool isGeldig = _idService.checkBelgianRrn(rrnReeks);

        if (isGeldig) {
          _showError("Rijksregister Checksum OK");
        } else {
          _showError("Checksum mismatch (RRN: $rrnReeks). Scan opnieuw.");
        }
      } else {
        _showError("RRN niet volledig gelezen. Probeer opnieuw");
      }

        List<String> lijnen = text.split('\n');
        for (var lijn in lijnen) {
          if (lijn.contains('<<') && !lijn.contains('IDBEL') && !RegExp(r'\d{6}').hasMatch(lijn)) {
            String naamRaw = lijn.replaceAll('<<', ' ').replaceAll('<', ' ').trim();
            
            if (naamRaw.isNotEmpty) {
              setState(() {
                _idScanController.text = naamRaw.toUpperCase();
              });
              debugPrint("NAAM GEVONDEN: $naamRaw");
            }
          }
        }
      } catch (e) {
        debugPrint("Parsing error achterkant: $e");
        _showError("Fout bij het lezen van de achterkant.");
      }
    } else if (isFront) {
      //OCR check voor vervaldatum op voorkant
      RegExp datumRegEx = RegExp(r"(\d{2}[\s.-]\d{2}[\s.-]\d{4})");
      Match? match = datumRegEx.firstMatch(text);
      if (match != null) {
        setState(() {
           _datumController.text = match.group(0)!;
        });
        _idService.checkVervaldatum(_datumController.text, _showError);
      }
    }
  }

  //met behulp van https://communityhistoryarchives.com/100-common-ocr-letter-misinterpretations/
  String fixOcrErrors(String input) {
  return input
      .replaceAll(RegExp(r'[oOQCDcC]'), '0')
      .replaceAll(RegExp(r'[LI|liJt]'), '1')
      .replaceAll(RegExp(r'[zZ]'), '2')
      .replaceAll(RegExp(r'[sS]'), '5')
      .replaceAll(RegExp(r'[b]'), '6')
      .replaceAll(RegExp(r'[B]'), '8')
      .replaceAll(RegExp(r'[gpq]'), '9');
}

  Future<void> _uploadImage(bool isFront) async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    if (image != null) {

      String recognizedText = await _idService.getRecognizedText(image.path);
      _processScannedData(recognizedText, image.path, isFront);

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
      _showError("Backend onbereikbaar.");
    } finally {
      setState(() => _isLoading = false);
    }

  }

Future<void> _biometricCheck() async {
  if (_frontPath == null || _frontPath!.isEmpty) {
    _showError("Scan eerst de ID-kaart.");
    return;
  }

  await Navigator.push(
    context,
    MaterialPageRoute(
      builder: (c) => CameraScannerWidget(
        instructie: "Scan gezicht", 
        onScanComplete: (txt, path) async {
          await _checkBiometrics(path);
        },
      ),
    ),
  );
}

Future<void> _checkBiometrics(String selfiePath) async {
  setState(() => _isLoading = true);

  try {
    final File? faceIdCrop = await _idService.extractFace(_frontPath!);
    
    final File? selfieCrop = await _idService.extractFace(selfiePath);

    if (faceIdCrop == null || selfieCrop == null) {
      _showError("Gezicht niet herkend. Zorg voor goede verlichting.");
      return;
    }

//vectoren vergelijken in embeddings
    double matchScore = await _idService.getSimilarityScore(faceIdCrop, selfieCrop);

    setState(() {
      _face = faceIdCrop;
      _liveSelfieFile = selfieCrop;
      _faceMatchScore = matchScore;
      
      if (matchScore > 0.60) {
        _matchResultaat = "GEZICHTSVERGELIJKING OK\nGelijkenis: ${(matchScore * 100).toStringAsFixed(1)}%";
      } else {
        _matchResultaat = "GEZICHTSVERGELIJKING MISLUKT\nGelijkenis: ${(matchScore * 100).toStringAsFixed(1)}%";
      }
    });
  } catch (e) {
    _showError("Biometrie fout: $e");
  } finally {
    setState(() => _isLoading = false);
  }
}

void _verifieerEID() {
  if (_bedrijfsData == null || _idScanController.text.isEmpty) {
    _showError("Scan eerst de ID en raadpleeg de KBO.");
    return;
  }

  final idNaam = _idScanController.text.toUpperCase();
  
  List<String> bestuurders = List<String>.from(_bedrijfsData!['directors']);
  bool isBestuurder = false;

  for (var kboNaam in bestuurders) {
    List<String> kboWoorden = kboNaam.toUpperCase().split(' ')
        .where((w) => w.length > 1)
        .toList();

    //checken of alle woorden in KBO naam voorkomen in ID naam (indien dat de klant meerdere namen heeft en de kbo ze niet allemaal bevat)
    bool alleKboWoordenOpId = kboWoorden.every((woord) => idNaam.contains(woord));

    if (alleKboWoordenOpId && kboWoorden.isNotEmpty) {
      isBestuurder = true;
      break;
    }
  }
    setState(() {
      _matchResultaat = isBestuurder 
          ? "IDENTITEIT BEVESTIGD\nBevoegde bestuurder gevonden." 
          : "TOEGANG GEWEIGERD\nGeen match gevonden in KBO directors.";
    });
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), duration: const Duration(seconds: 4)));
  }

  Widget _buildStepButton(String label, bool isFront, bool done) {
    return Expanded(
      child: Column(
        children: [
          ElevatedButton.icon(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (c) => CameraScannerWidget(
                  instructie: "Scan $label",
                  onScanComplete: (txt, path) => _processScannedData(txt, path, isFront),
                ),
              ),
            ),
            icon: Icon(isFront ? Icons.face : Icons.vpn_key, color: done ? Colors.green : Colors.white),
            label: Text(label),
            style: ElevatedButton.styleFrom(
              backgroundColor: done ? Colors.green.shade700 : Colors.blueGrey,
              foregroundColor: Colors.white,
            ),
          ),
          TextButton.icon(
            onPressed: () => _uploadImage(isFront),
            icon: const Icon(Icons.upload_file, size: 16),
            label: const Text("PNG/JPG UPLOAD", style: TextStyle(fontSize: 10)),
          ),
        ],
      ),
    );
  }

@override
Widget build(BuildContext context) {
  return Scaffold(
    appBar: AppBar(
      title: const Text("Scrada KYC Portaal"),
      backgroundColor: const Color(0xFF8B0000),
      foregroundColor: Colors.white,
    ),
    body: KycPaginaLayout(
      // Stap 1: KBO
      kboSectie: KycSectionCard(
        title: "1. KBO Bedrijfscheck",
        icon: Icons.business,
        children: [
          TextField(controller: _kboController, decoration: const InputDecoration(labelText: "Ondernemingsnummer")),
          const SizedBox(height: 10),
          ElevatedButton(
            onPressed: _isLoading ? null : _voerKycUit,
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF8B0000), foregroundColor: Colors.white),
            child: _isLoading ? const CircularProgressIndicator(color: Colors.white) : const Text("RAADPLEEG KBO"),
          ),
        ],
      ),
      
      // Stap 2: Bedrijfsinfo (alleen als er data is)
      bedrijfsInfo: _bedrijfsData != null 
        ? BedrijfsInfoCard(name: _bedrijfsData!['name'], directors: List<String>.from(_bedrijfsData!['directors'])) 
        : null,

      // Stap 3: Identiteit
      identiteitSectie: _bedrijfsData != null ? KycSectionCard(
        title: "2. Identiteitscontrole",
        icon: Icons.badge,
        children: [
          TextField(controller: _idScanController, decoration: const InputDecoration(labelText: "Naam uit ID")),
          TextField(controller: _datumController, decoration: const InputDecoration(labelText: "Vervaldatum")),
          const SizedBox(height: 20),
          Row(children: [
            _buildStepButton("VOORKANT", true, _frontPath != null),
            const SizedBox(width: 10),
            _buildStepButton("ACHTERKANT", false, _backPath != null),
          ]),
          const SizedBox(height: 20),
          SizedBox(width: double.infinity, child: ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.black87, foregroundColor: Colors.white),
            onPressed: _verifieerEID,
            child: const Text("VERIFIEER BESTUURDER"),
          )),
          if (_matchResultaat.isNotEmpty && _faceMatchScore == null) 
             Padding(
               padding: const EdgeInsets.only(top: 20),
               child: Text(_matchResultaat, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.bold)),
             ),
        ],
      ) : null,

      // Stap 4: Biometrie
      biometrieSectie: (_bedrijfsData != null && _frontPath != null) ? KycSectionCard(
        title: "3. Biometrische Verificatie",
        icon: Icons.face_retouching_natural,
        children: [
          if (_faceMatchScore != null) 
            BiometricResultWidget(face: _face, selfie: _liveSelfieFile, score: _faceMatchScore, matchResultaat: _matchResultaat),
          ElevatedButton.icon(
            onPressed: _isLoading ? null : _biometricCheck,
            icon: const Icon(Icons.camera_front),
            label: const Text("VERGELIJK GEZICHTEN"),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF8B0000), foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 12)),
          ),
        ],
      ) : null,
    ),
  );
}
}