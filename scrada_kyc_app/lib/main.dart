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
      theme: ThemeData(primarySwatch: Colors.blue),
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
  String _resultaat = "Vul een ondernemingsnummer in.";
  bool _isLoading = false;

Future<void> _checkKbo() async {
  setState(() {
    _isLoading = true;
    _resultaat = "Zoeken in de KBO...";
  });

  try {
    final ondernemingsnummer = _kboController.text;

    if (ondernemingsnummer.isEmpty) {
      setState(() {
        _resultaat = "Geef een ondernemingsnummer in.";
        _isLoading = false;
      });
      return;
    }

    final url = Uri.parse('http://127.0.0.1:5012/api/kbo/$ondernemingsnummer');

    final response = await http.get(url);

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final directors = data['directors'] ?? [];

      setState(() {
        _resultaat = """
Bedrijf gevonden.

Naam: ${data['name']}
Status: ${data['status']}
Risico: ${data['risk_score']}

Bestuurders: ${directors.isEmpty ? "Niet beschikbaar" : directors.join(', ')}
""";
      });
    } else {
      setState(() {
        _resultaat = "Fout: Kon het bedrijf niet vinden (Status: ${response.statusCode})";
      });
    }
  } catch (e) {
    setState(() {
      _resultaat = "Kan de backend niet bereiken";
    });
  } finally {
    setState(() {
      _isLoading = false;
    });
  }
}

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Scrada KYC PoC')),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              "Stap 1: KBO Verificatie", 
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _kboController,
              decoration: const InputDecoration(
                labelText: 'Ondernemingsnummer',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _isLoading ? null : _checkKbo,
              child: const Text('Check KBO via Backend'),
            ),
            const SizedBox(height: 32),
            Container(
              padding: const EdgeInsets.all(16),
              color: Colors.blueGrey[50],
              child: Text(
                _resultaat, 
                style: const TextStyle(fontSize: 16)
              ),
            ),
          ],
        ),
      ),
    );
  }
}