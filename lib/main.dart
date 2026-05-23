import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'vistas/pantalla_splash.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(const CampusSyncApp());
}

class CampusSyncApp extends StatelessWidget {
  const CampusSyncApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'CampusSync',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const PantallaSplash(), // Inicia directo en el Splash Screen
    );
  }
}