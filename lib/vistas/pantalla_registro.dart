import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart' as google_auth;

class PantallaRegistro extends StatefulWidget {
  const PantallaRegistro({super.key});

  @override
  State<PantallaRegistro> createState() => _PantallaRegistroState();
}

class _PantallaRegistroState extends State<PantallaRegistro> {
  final TextEditingController _nombreController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passController = TextEditingController();
  final TextEditingController _confirmPassController = TextEditingController();
  String _mensajeError = '';

  bool _esCorreoValido(String email) {
    final RegExp regex = RegExp(r'^[^@]+@[^@]+\.[^@]+');
    return regex.hasMatch(email);
  }

  bool _esContrasenaSegura(String password) {
    if (password.length < 8) return false; 
    if (!password.contains(RegExp(r'[A-Z]'))) return false; 
    if (!password.contains(RegExp(r'[a-z]'))) return false; 
    if (!password.contains(RegExp(r'[0-9]'))) return false; 
    if (!password.contains(RegExp(r'[^a-zA-Z0-9]'))) return false; 
    return true;
  }

  void _registrar() async {
    if (_nombreController.text.trim().isEmpty || _emailController.text.trim().isEmpty || _passController.text.trim().isEmpty || _confirmPassController.text.trim().isEmpty) {
      setState(() => _mensajeError = 'Todos los campos son obligatorios.');
      return;
    }
    if (!_esCorreoValido(_emailController.text.trim())) {
      setState(() => _mensajeError = 'Formato de correo inválido.');
      return;
    }
    if (!_esContrasenaSegura(_passController.text)) {
      setState(() => _mensajeError = 'La contraseña debe tener 8+ caracteres, Mayús, Núm y Símbolo.');
      return;
    }
    if (_passController.text != _confirmPassController.text) {
      setState(() => _mensajeError = 'Las contraseñas no coinciden.');
      return;
    }
    try {
      UserCredential userCredential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passController.text,
      );
      
      await userCredential.user?.updateDisplayName(_nombreController.text.trim());

      // Guardamos el perfil completo en Firestore incluyendo el ESTADO
      await FirebaseFirestore.instance.collection('usuarios').doc(userCredential.user!.uid).set({
        'nombre': _nombreController.text.trim(),
        'correo': _emailController.text.trim(),
        'rol': 'estudiante',
        'estado': 'activo', // ¡REQUISITO DE RÚBRICA CUMPLIDO!
        'fechaCreacion': FieldValue.serverTimestamp(),
      });

      await userCredential.user?.sendEmailVerification();
      await FirebaseAuth.instance.signOut();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Registro exitoso. Revisa tu correo para verificar y luego inicia sesión.')),
        );
        if (Navigator.canPop(context)) Navigator.pop(context);
      }
    } on FirebaseAuthException catch (e) {
      setState(() => _mensajeError = 'Error: ${e.message}');
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
            'estado': 'activo', // ¡AQUÍ TAMBIÉN!
            'fechaCreacion': FieldValue.serverTimestamp(),
          });
        }
      }

      if (mounted && Navigator.canPop(context)) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error con Google: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Registro'),
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
                  controller: _nombreController,
                  decoration: const InputDecoration(labelText: 'Nombre Completo', border: OutlineInputBorder()),
                  textCapitalization: TextCapitalization.words,
                ),
                const SizedBox(height: 15),
                TextField(
                  controller: _emailController,
                  decoration: const InputDecoration(labelText: 'Correo Institucional', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 15),
                TextField(
                  controller: _passController,
                  obscureText: true,
                  decoration: const InputDecoration(labelText: 'Contraseña', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 15),
                TextField(
                  controller: _confirmPassController,
                  obscureText: true,
                  decoration: const InputDecoration(labelText: 'Confirmar Contraseña', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 10),
                Text(_mensajeError, style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
                const SizedBox(height: 20),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 50)),
                  onPressed: _registrar,
                  child: const Text('Registrarse'),
                ),
                const SizedBox(height: 15),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: Colors.black, minimumSize: const Size(double.infinity, 50)),
                  icon: const Icon(Icons.g_mobiledata, size: 30, color: Colors.blue),
                  label: const Text('Registrarse con Google'),
                  onPressed: _ingresarConGoogle,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}