import 'package:flutter/material.dart';
import 'kycScreen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MaterialApp(
    debugShowCheckedModeBanner: false,
    home: KycScreen(),
  ));
}