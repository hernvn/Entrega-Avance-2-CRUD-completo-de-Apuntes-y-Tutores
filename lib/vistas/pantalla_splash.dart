import 'package:flutter/material.dart';
import 'auth_gate.dart';

class PantallaSplash extends StatefulWidget {
  const PantallaSplash({super.key});

  @override
  State<PantallaSplash> createState() => _PantallaSplashState();
}

class _PantallaSplashState extends State<PantallaSplash> {
  @override
  void initState() {
    super.initState();
    _iniciarCarga();
  }

  void _iniciarCarga() async {
    // Tiempo de espera para mostrar el logo corporativo
    await Future.delayed(const Duration(seconds: 2));
    
    if (!mounted) return;

    // Redirigir al guardián de autenticación reactivo
    Navigator.pushReplacement(
      context, 
      MaterialPageRoute(builder: (context) => const AuthGate())
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.blue.shade700,
      body: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.school, size: 120, color: Colors.white),
            SizedBox(height: 20),
            Text(
              'CampusSync', 
              style: TextStyle(
                fontSize: 35, 
                fontWeight: FontWeight.bold, 
                color: Colors.white,
                letterSpacing: 2.0,
              )
            ),
            SizedBox(height: 40),
            CircularProgressIndicator(color: Colors.white),
          ],
        ),
      ),
    );
  }
}