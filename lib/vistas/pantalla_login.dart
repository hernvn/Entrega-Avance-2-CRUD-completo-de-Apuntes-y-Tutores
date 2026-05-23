import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart' as google_auth;
import 'pantalla_registro.dart';
import 'pantalla_recuperar.dart';

class PantallaLogin extends StatefulWidget {
  const PantallaLogin({super.key});

  @override
  State<PantallaLogin> createState() => _PantallaLoginState();
}

class _PantallaLoginState extends State<PantallaLogin> {
  final TextEditingController _userController = TextEditingController();
  final TextEditingController _passController = TextEditingController();
  String _mensajeError = '';

  bool _esCorreoValido(String email) {
    final RegExp regex = RegExp(r'^[^@]+@[^@]+\.[^@]+');
    return regex.hasMatch(email);
  }

  void _validarIngreso() async {
    if (_userController.text.trim().isEmpty || _passController.text.trim().isEmpty) {
      setState(() => _mensajeError = 'Debes ingresar tu correo y contraseña.');
      return;
    }
    
    if (!_esCorreoValido(_userController.text.trim())) {
      setState(() => _mensajeError = 'El formato del correo no es válido.');
      return;
    }
    
    setState(() => _mensajeError = 'Iniciando sesión...');

    try {
      UserCredential userCredential = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _userController.text.trim(),
        password: _passController.text,
      );

      if (userCredential.user != null && !userCredential.user!.emailVerified) {
        await FirebaseAuth.instance.signOut();
        setState(() => _mensajeError = 'Debes verificar tu correo antes de entrar. Revisa tu bandeja de entrada.');
        return;
      }

    } on FirebaseAuthException catch (e) {
      String mensaje = '';
      if (e.code == 'user-not-found' || e.code == 'invalid-credential') {
        mensaje = 'Correo no registrado o contraseña incorrecta.';
      } else if (e.code == 'wrong-password') {
        mensaje = 'Contraseña incorrecta.';
      } else {
        mensaje = 'Error de conexión: ${e.message}';
      }
      setState(() => _mensajeError = mensaje);
    }
  }

  void _ingresarConGoogle() async {
    try {
      final google_auth.GoogleSignIn googleSignIn = google_auth.GoogleSignIn();
      final google_auth.GoogleSignInAccount? googleUser = await googleSignIn.signIn();
      if (googleUser == null) return; 

      final google_auth.GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );
      
      UserCredential userCredential = await FirebaseAuth.instance.signInWithCredential(credential);
      User? user = userCredential.user;

      if (user != null) {
        DocumentSnapshot userDoc = await FirebaseFirestore.instance.collection('usuarios').doc(user.uid).get();
        if (!userDoc.exists) {
          await FirebaseFirestore.instance.collection('usuarios').doc(user.uid).set({
            'nombre': user.displayName ?? 'Estudiante UA',
            'correo': user.email ?? '',
            'rol': 'estudiante',
            'estado': 'activo', // Se asegura el campo de estado al loguearse por primera vez con Google
            'fechaCreacion': FieldValue.serverTimestamp(),
          });
        }
      }

      if (mounted) Navigator.of(context).popUntil((route) => route.isFirst);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error con Google: ${e.toString()}')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('CampusSync - Ingreso'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(30.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.school, size: 100, color: Colors.blue),
                const SizedBox(height: 20),
                TextField(
                  controller: _userController,
                  autofocus: true,
                  decoration: const InputDecoration(labelText: 'Correo Institucional', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 15),
                TextField(
                  controller: _passController,
                  obscureText: true,
                  decoration: const InputDecoration(labelText: 'Contraseña', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 10),
                Text(_mensajeError, style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
                const SizedBox(height: 20),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 50)),
                  onPressed: _validarIngreso,
                  child: const Text('Entrar a la Universidad'),
                ),
                const SizedBox(height: 15),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.black,
                    minimumSize: const Size(double.infinity, 50),
                  ),
                  icon: const Icon(Icons.g_mobiledata, size: 30, color: Colors.blue),
                  label: const Text('Ingresar con Google'),
                  onPressed: _ingresarConGoogle,
                ),
                const SizedBox(height: 20),
                TextButton(
                  onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const PantallaRegistro())),
                  child: const Text('¿No tienes cuenta? Regístrate'),
                ),
                TextButton(
                  onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const PantallaRecuperar())),
                  child: const Text('¿Olvidaste tu contraseña?'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}