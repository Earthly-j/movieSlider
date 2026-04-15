import 'package:flutter/material.dart';
import 'screens/home_screen.dart';

void main() {
  runApp(const TmdbSliderApp());
}

class TmdbSliderApp extends StatelessWidget {
  const TmdbSliderApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: "hello",
      debugShowCheckedModeBanner: false,
      theme: ThemeData(colorSchemeSeed: const Color(0xFF1DB954), brightness: Brightness.dark, useMaterial3: true),
      home: const HomeScreen(),
    );
  }
}
