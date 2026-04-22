import 'package:flutter/material.dart';
import 'dart:io';

class KycPaginaLayout extends StatelessWidget {
  final Widget kboSectie;
  final Widget? bedrijfsInfo;
  final Widget? identiteitSectie;
  final Widget? biometrieSectie;
  final Widget? verificatieSectie;

  const KycPaginaLayout({
    super.key,
    required this.kboSectie,
    this.bedrijfsInfo,
    this.identiteitSectie,
    this.biometrieSectie,
    this.verificatieSectie,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          kboSectie,
          if (bedrijfsInfo != null) bedrijfsInfo!,
          if (identiteitSectie != null) identiteitSectie!,
          if (biometrieSectie != null) biometrieSectie!,
          if (verificatieSectie != null) verificatieSectie!,
        ],
      ),
    );
  }
}

class KycSectionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<Widget> children;

  const KycSectionCard({
    super.key, 
    required this.title, 
    required this.icon, 
    required this.children
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4, 
      margin: const EdgeInsets.only(bottom: 15), 
      child: Padding(
        padding: const EdgeInsets.all(15), 
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch, 
          children: [
            Row(children: [
              Icon(icon, color: const Color(0xFF8B0000)), 
              const SizedBox(width: 10), 
              Text(title, style: const TextStyle(fontWeight: FontWeight.bold))
            ]), 
            const Divider(), 
            ...children
          ]
        )
      )
    );
  }
}

class BedrijfsInfoCard extends StatelessWidget {
  final String name;
  final List<String> directors;

  const BedrijfsInfoCard({super.key, required this.name, required this.directors});

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.green.shade50, 
      child: ListTile(
        title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold)), 
        subtitle: Text("Bestuurders: ${directors.join(', ')}")
      )
    );
  }
}

class BiometricResultWidget extends StatelessWidget {
  final File? face;
  final File? selfie;
  final double? score;
  final String matchResultaat;

  const BiometricResultWidget({
    super.key, 
    this.face, 
    this.selfie, 
    this.score, 
    required this.matchResultaat
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            if (face != null) 
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.file(face!, width: 100, height: 100, fit: BoxFit.cover),
              ),
            if (selfie != null) 
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.file(selfie!, width: 100, height: 100, fit: BoxFit.cover),
              ),
          ],
        ),
        const SizedBox(height: 15),
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: (score != null && score! > 0.70) ? Colors.green.shade100 : Colors.red.shade100,
            borderRadius: BorderRadius.circular(5),
          ),
          child: Text(
            matchResultaat,
            textAlign: TextAlign.center,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
        const SizedBox(height: 15),
      ],
    );
  }
}

class VerificatieWidget extends StatelessWidget {
  final VoidCallback? onPressed;
  final String matchResultaat;
  final double? faceMatchScore;

  const VerificatieWidget({
    super.key,
    required this.onPressed,
    required this.matchResultaat,
    this.faceMatchScore,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.black87,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 15),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: onPressed,
            child: const Text(
              "VERIFIEER BESTUURDER",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
        ),
        
        if (matchResultaat.isNotEmpty && faceMatchScore == null)
          Padding(
            padding: const EdgeInsets.only(top: 20),
            child: Text(
              matchResultaat,
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
      ],
    );
  }
}