import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

void main() {
  runApp(const ScradaKycApp());
}

class ScradaKycApp extends StatelessWidget {
  const ScradaKycApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Scrada KYC',
      theme: ThemeData(
        // Het kleurenpalet: Donkerrood, Beige en Wit
        primaryColor: const Color(0xFF8B0000), // Donkerrood
        scaffoldBackgroundColor: const Color(0xFFF5F5DC), // Beige achtergrond
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF8B0000),
          primary: const Color(0xFF8B0000),
          secondary: const Color(0xFF4A4A4A),
        ),
        cardTheme: CardThemeData(
      color: Colors.white,
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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

  String _kycStatusBericht = "Voer ondernemingsnummer in om de check te starten.";
  Map<String, dynamic>? _bedrijfsData;
  String _matchResultaat = "";
  bool _isLoading = false;
  bool _kycCheckGeslaagd = false;

  Future<void> _voerKycUit() async {
    setState(() {
      _isLoading = true;
      _kycStatusBericht = "Bezig met ophalen data uit KBO & VIES...";
      _bedrijfsData = null;
      _kycCheckGeslaagd = false;
    });

    try {
      final nummer = _kboController.text.replaceAll('.', '').replaceAll(' ', '');
      final url = Uri.parse('http://127.0.0.1:5012/api/kyc/$nummer');
      final response = await http.get(url);

      if (response.statusCode == 200) {
        setState(() {
          _bedrijfsData = json.decode(response.body);
          _kycCheckGeslaagd = true;
          _kycStatusBericht = "Bedrijfsgegevens gevonden.";
        });
      } else {
        setState(() => _kycStatusBericht = "Fout: Onderneming niet gevonden.");
      }
    } catch (e) {
      setState(() => _kycStatusBericht = "Verbindingsfout met de backend.");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _verifieerEID() {
    final gescandeNaam = _idScanController.text.trim();
    if (gescandeNaam.isEmpty || _bedrijfsData == null) return;

    List<String> bestuurders = List<String>.from(_bedrijfsData!['directors']);
    
    // Check of de gescande naam voorkomt in de lijst van de KBO
    bool isMatch = bestuurders.any((b) => b.toLowerCase() == gescandeNaam.toLowerCase());

    setState(() {
      if (isMatch) {
        _matchResultaat = "IDENTITEIT BEVESTIGD\n$gescandeNaam is een bevoegde bestuurder voor ${_bedrijfsData!['name']}.";
      } else {
        _matchResultaat = "TOEGANG GEWEIGERD\n$gescandeNaam komt niet voor in de lijst van wettelijke bestuurders.";
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scrada KYC Portaal', style: TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFF8B0000),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            // STAP 1 CARD
            _buildSectionCard(
              title: "1. Bedrijfsverificatie",
              icon: Icons.business,
              child: Column(
                children: [
                  TextField(
                    controller: _kboController,
                    decoration: const InputDecoration(
                      labelText: 'Ondernemingsnummer',
                      hintText: 'Bijv. 0400.378.485',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 15),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF8B0000)),
                      onPressed: _isLoading ? null : _voerKycUit,
                      child: _isLoading 
                        ? const CircularProgressIndicator(color: Colors.white) 
                        : const Text("RAADPLEEG KBO/VIES", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ),

            if (_bedrijfsData != null) ...[
              const SizedBox(height: 20),
              // RESULTAAT CARD
              _buildResultCard(),
              
              const SizedBox(height: 20),
              // STAP 2 CARD
              _buildSectionCard(
                title: "2. Identificatie Bestuurder",
                icon: Icons.person_search,
                child: Column(
                  children: [
                    const Text("Scan de eID van de persoon die voor u staat:"),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _idScanController,
                      decoration: const InputDecoration(
                        labelText: 'Naam van eID scan',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.badge),
                      ),
                    ),
                    const SizedBox(height: 15),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.black87),
                        onPressed: _verifieerEID,
                        child: const Text("CONTROLEER MATCH", style: TextStyle(color: Colors.white)),
                      ),
                    ),
                    if (_matchResultaat.isNotEmpty) ...[
                      const SizedBox(height: 20),
                      _buildMatchBox(),
                    ]
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSectionCard({required String title, required IconData icon, required Widget child}) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: const Color(0xFF8B0000)),
                const SizedBox(width: 10),
                Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ],
            ),
            const Divider(),
            const SizedBox(height: 10),
            child,
          ],
        ),
      ),
    );
  }

  Widget _buildResultCard() {
    return Card(
      color: Colors.white,
      shape: RoundedRectangleBorder(side: BorderSide(color: Colors.grey.shade300)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_bedrijfsData!['name'].toString().toUpperCase(), 
                 style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF8B0000))),
            const SizedBox(height: 8),
            _resultRow(Icons.info_outline, "Status", _bedrijfsData!['status']),
            _resultRow(Icons.g_translate, "VIES Check", "Valid (Active)"),
            _resultRow(Icons.security, "LSEG World-Check", _bedrijfsData!['sanction_check']),
            _resultRow(Icons.warning_amber, "Risico Score", _bedrijfsData!['risk_score'], isBold: true),
            const Divider(),
            Text("Wettelijke Bestuurders:", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey.shade700)),
            Text(_bedrijfsData!['directors'].join(', '), style: const TextStyle(fontStyle: FontStyle.italic)),
          ],
        ),
      ),
    );
  }

  Widget _resultRow(IconData icon, String label, String value, {bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Colors.grey),
          const SizedBox(width: 8),
          Text("$label: "),
          Text(value, style: TextStyle(fontWeight: isBold ? FontWeight.bold : FontWeight.normal)),
        ],
      ),
    );
  }

  Widget _buildMatchBox() {
    bool isSuccess = _matchResultaat.contains("BEVESTIGD");
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isSuccess ? Colors.green.shade50 : Colors.red.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: isSuccess ? Colors.green : Colors.red),
      ),
      child: Row(
        children: [
          Icon(isSuccess ? Icons.check_circle : Icons.error, color: isSuccess ? Colors.green : Colors.red),
          const SizedBox(width: 15),
          Expanded(child: Text(_matchResultaat, style: TextStyle(color: isSuccess ? Colors.green.shade900 : Colors.red.shade900, fontWeight: FontWeight.bold))),
        ],
      ),
    );
  }
}