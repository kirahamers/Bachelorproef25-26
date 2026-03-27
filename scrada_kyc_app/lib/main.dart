import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:camera/camera.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:permission_handler/permission_handler.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ScradaKycApp());
}

class ScradaKycApp extends StatelessWidget {
  const ScradaKycApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Scrada KYC',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        primaryColor: const Color(0xFF8B0000),
        scaffoldBackgroundColor: const Color(0xFFF5F5DC),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF8B0000),
          primary: const Color(0xFF8B0000),
          surface: Colors.white,
        ),
        cardTheme: const CardThemeData(
          color: Colors.white,
          elevation: 4,
          margin: EdgeInsets.symmetric(vertical: 10),
        ),
      ),
      home: const KycScreen(),
    );
  }
}

class KycScreen extends StatefulWidget {
  const KycScreen({super.key});

  @override
  State<KycScreen> createState() => _KycScreenState();
}

class _KycScreenState extends State<KycScreen> {
  final TextEditingController _kboController = TextEditingController();
  final TextEditingController _idScanController = TextEditingController();

  Map<String, dynamic>? _bedrijfsData;
  String _matchResultaat = "";
  bool _isLoading = false;

  Future<void> _voerKycUit() async {
    setState(() {
      _isLoading = true;
      _bedrijfsData = null;
      _matchResultaat = "";
    });

    try {
      final nummer = _kboController.text.replaceAll('.', '').replaceAll(' ', '');
      //AANPASSEN BIJ VERANDERING IP
      //final url = Uri.parse('http://127.0.0.1:5012/api/kyc/$nummer');
      //EMULATOR
      final url = Uri.parse('http://10.0.2.2:5012/api/kyc/$nummer');
      final response = await http.get(url);

      if (response.statusCode == 200) {
        setState(() => _bedrijfsData = json.decode(response.body));
      } else {
        _showError("Onderneming niet gevonden.");
      }
    } catch (e) {
      _showError("Backend onbereikbaar. Controleer je verbinding. error: ${e.toString()}");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _startScan() async {
    var status = await Permission.camera.request();
    if (!status.isGranted) {
      _showError("Cameratoegang is vereist om te scannen.");
      return;
    }

    final cameras = await availableCameras();
    if (cameras.isEmpty) {
      _showError("Geen camera gevonden op dit toestel.");
      return;
    }

    await showGeneralDialog(
      context: context,
      barrierDismissible: false,
      pageBuilder: (context, anim1, anim2) => CameraScannerWidget(
        camera: cameras.first,
        onTextDetected: (text) {
          setState(() {
            _idScanController.text = _extraheerNaam(text);
          });
        },
      ),
    );
  }

  String _extraheerNaam(String text) {
    List<String> lijnen = text.split('\n');
    for (int i = 0; i < lijnen.length; i++) {
      String l = lijnen[i].toLowerCase();
      if ((l.contains("naam") || l.contains("nom")) && i + 1 < lijnen.length) {
        return lijnen[i + 1].trim().toUpperCase();
      }
    }
    return lijnen.isNotEmpty ? lijnen[0].trim().toUpperCase() : "";
  }

  void _verifieerEID() {
    if (_bedrijfsData == null) return;
    final gescandeNaam = _idScanController.text.trim();
    if (gescandeNaam.isEmpty) {
      _showError("Scan eerst een eID of vul een naam in.");
      return;
    }

    List<String> bestuurders = List<String>.from(_bedrijfsData!['directors']);
    bool isMatch = bestuurders.any((b) => b.toLowerCase() == gescandeNaam.toLowerCase());

    setState(() {
      _matchResultaat = isMatch 
        ? "IDENTITEIT BEVESTIGD \n$gescandeNaam is een bevoegde bestuurder."
        : "TOEGANG GEWEIGERD \n$gescandeNaam is niet bevoegd.";
    });
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scrada KYC Portaal', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF8B0000),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            _buildCard("1. Bedrijfsverificatie", Icons.business, [
              TextField(
                controller: _kboController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Ondernemingsnummer', 
                  hintText: '0400.378.485',
                  border: OutlineInputBorder()
                ),
              ),
              const SizedBox(height: 15),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF8B0000),
                    foregroundColor: Colors.white
                  ),
                  onPressed: _isLoading ? null : _voerKycUit,
                  child: _isLoading 
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) 
                    : const Text("RAADPLEEG KBO/VIES"),
                ),
              ),
            ]),
            if (_bedrijfsData != null) ...[
              const SizedBox(height: 10),
              _buildResultCard(),
              const SizedBox(height: 10),
              _buildCard("2. Identificatie Bestuurder", Icons.person_search, [
                const Text("Scan de eID kaart van de bestuurder:"),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _idScanController,
                        decoration: const InputDecoration(labelText: 'Gescande Naam', border: OutlineInputBorder()),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton.filled(
                      style: IconButton.styleFrom(backgroundColor: const Color(0xFF8B0000)),
                      onPressed: _startScan,
                      icon: const Icon(Icons.camera_alt, color: Colors.white),
                    ),
                  ],
                ),
                const SizedBox(height: 15),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.black87, foregroundColor: Colors.white),
                    onPressed: _verifieerEID,
                    child: const Text("CONTROLEER MATCH"),
                  ),
                ),
                if (_matchResultaat.isNotEmpty) _buildMatchBox(),
              ]),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildCard(String title, IconData icon, List<Widget> children) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(children: [Icon(icon, color: const Color(0xFF8B0000)), const SizedBox(width: 10), Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16))]),
            const Divider(),
            ...children
          ],
        ),
      ),
    );
  }

  Widget _buildResultCard() {
    return Card(
      shape: RoundedRectangleBorder(side: BorderSide(color: Colors.grey.shade300)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_bedrijfsData!['name'].toString().toUpperCase(), style: const TextStyle(color: Color(0xFF8B0000), fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 4),
            const Text("Status: ACTIVE | VIES: Valid", style: TextStyle(color: Colors.green, fontWeight: FontWeight.w600)),
            const Divider(),
            Text("Bestuurders in KBO:", style: TextStyle(color: Colors.grey.shade700, fontWeight: FontWeight.bold)),
            Text(_bedrijfsData!['directors'].join(', '), style: const TextStyle(fontStyle: FontStyle.italic)),
          ],
        ),
      ),
    );
  }

  Widget _buildMatchBox() {
    bool ok = _matchResultaat.contains("✅");
    return Container(
      margin: const EdgeInsets.only(top: 15),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: ok ? Colors.green.shade50 : Colors.red.shade50, 
        border: Border.all(color: ok ? Colors.green : Colors.red), 
        borderRadius: BorderRadius.circular(8)
      ),
      child: Row(
        children: [
          Icon(ok ? Icons.check_circle : Icons.error, color: ok ? Colors.green : Colors.red),
          const SizedBox(width: 10),
          Expanded(child: Text(_matchResultaat, style: TextStyle(color: ok ? Colors.green.shade900 : Colors.red.shade900, fontWeight: FontWeight.bold))),
        ],
      ),
    );
  }
}

class CameraScannerWidget extends StatefulWidget {
  final CameraDescription camera;
  final Function(String) onTextDetected;
  const CameraScannerWidget({super.key, required this.camera, required this.onTextDetected});

  @override
  State<CameraScannerWidget> createState() => _CameraScannerWidgetState();
}

class _CameraScannerWidgetState extends State<CameraScannerWidget> {
  CameraController? _controller;
  final _recognizer = TextRecognizer();
  bool _isInitializing = true;

  @override
  void initState() {
    super.initState();
    _setupCamera();
  }

  Future<void> _setupCamera() async {
    _controller = CameraController(widget.camera, ResolutionPreset.high, enableAudio: false);
    try {
      await _controller!.initialize();
    } catch (e) {
      debugPrint("Camera error: $e");
    }
    if (mounted) {
      setState(() => _isInitializing = false);
    }
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
      return const Scaffold(backgroundColor: Colors.black, body: Center(child: CircularProgressIndicator(color: Colors.white)));
    }
    
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(backgroundColor: Colors.transparent, iconTheme: const IconThemeData(color: Colors.white)),
      body: Stack(
        children: [
          Center(child: CameraPreview(_controller!)),
          // Scan frame
          Center(
            child: Container(
              width: MediaQuery.of(context).size.width * 0.8,
              height: 200,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.white, width: 2),
                borderRadius: BorderRadius.circular(12)
              ),
            ),
          ),
          Positioned(
            bottom: 50,
            left: 0,
            right: 0,
            child: Column(
              children: [
                const Text("Plaats de eID in het kader", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                const SizedBox(height: 20),
                FloatingActionButton(
                  backgroundColor: const Color(0xFF8B0000),
                  onPressed: () async {
                    try {
                      final img = await _controller!.takePicture();
                      final recognized = await _recognizer.processImage(InputImage.fromFilePath(img.path));
                      widget.onTextDetected(recognized.text);
                      if (mounted) Navigator.pop(context);
                    } catch (e) {
                      debugPrint("Capture error: $e");
                    }
                  },
                  child: const Icon(Icons.camera_alt, color: Colors.white),
                ),
              ],
            ),
          )
        ],
      ),
    );
  }
}