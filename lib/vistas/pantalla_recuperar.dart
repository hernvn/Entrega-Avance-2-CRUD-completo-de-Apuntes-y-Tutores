import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

class PantallaRecuperar extends StatefulWidget {
  const PantallaRecuperar({super.key});

  @override
  State<PantallaRecuperar> createState() => _PantallaRecuperarState();
}

class _PantallaRecuperarState extends State<PantallaRecuperar> {
  final TextEditingController _emailController = TextEditingController();
  String _mensaje = '';

  void _recuperar() async {
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: _emailController.text);
      setState(() => _mensaje = 'Correo de recuperación enviado.');
    } catch (e) {
      setState(() => _mensaje = 'Error: ${e.toString()}');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Recuperar Contraseña'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(30.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.email, size: 100, color: Colors.blue),
            const SizedBox(height: 20),
            TextField(
              controller: _emailController,
              decoration: const InputDecoration(labelText: 'Correo Institucional', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 10),
            Text(_mensaje, style: const TextStyle(color: Colors.blue)),
            const SizedBox(height: 20),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue, 
                foregroundColor: Colors.white, 
                minimumSize: const Size(double.infinity, 50)
              ),
              onPressed: _recuperar, 
              child: const Text('Enviar Correo de Recuperación'),
            ),
          ],
        ),
      ),
    );
  }
}