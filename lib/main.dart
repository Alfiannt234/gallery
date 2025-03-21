import 'package:flutter/material.dart';
import 'package:galeri/splash_screen.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Gallery',
      theme: ThemeData(
        primaryColor: const Color(0xFF767676),
        colorScheme: const ColorScheme.light(
           secondary: Color(0xFFE5002A),
        ),
      ),
      home: const SplashScreen(), // SplashScreen sebagai halaman awal
    );
  }
}
