import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'pantalla_login.dart';
import 'pantalla_inicio.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        // Mientras Firebase determina si hay una sesión activa
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        
        // Si el usuario está autenticado y su correo verificado, va al Inicio
        if (snapshot.hasData) {
          if (snapshot.data!.emailVerified) {
            return const PantallaInicio();
          }
        }
        
        // Si no hay usuario o no está verificado, lo manda al Login
        return const PantallaLogin();
      },
    );
  }
}