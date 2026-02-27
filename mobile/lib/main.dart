import 'package:flutter/material.dart';
import 'package:vocal/page/vocal_home_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const VocalApp());
}

class VocalApp extends StatelessWidget {
  const VocalApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Vocal',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0A0F1C),
      ),
      home: const VocalHomeScreen(),
    );
  }
}
