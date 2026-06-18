import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart' as google_auth;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'pantalla_dashboard.dart';

class PantallaPerfil extends StatefulWidget {
  const PantallaPerfil({super.key});

  @override
  State<PantallaPerfil> createState() => _PantallaPerfilState();
}

class _PantallaPerfilState extends State<PantallaPerfil> {
  User? user = FirebaseAuth.instance.currentUser;

  bool _esContrasenaSegura(String password) {
    if (password.length < 8) return false;
    if (!password.contains(RegExp(r'[A-Z]'))) return false;
    if (!password.contains(RegExp(r'[a-z]'))) return false;
    if (!password.contains(RegExp(r'[0-9]'))) return false;
    if (!password.contains(RegExp(r'[^a-zA-Z0-9]'))) return false;
    return true;
  }

  void _editarNombre() {
    TextEditingController nombreController = TextEditingController(text: user?.displayName ?? '');
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Editar Nombre'),
          content: TextField(
            controller: nombreController,
            autofocus: true,
            decoration: const InputDecoration(hintText: "Ingresa tu nuevo nombre"),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (nombreController.text.trim().isNotEmpty) {
                  await user?.updateDisplayName(nombreController.text.trim());
                  await user?.reload();
                  
                  if (!dialogContext.mounted) return;
                  Navigator.pop(dialogContext);
                  
                  if (!mounted) return;
                  setState(() {
                    user = FirebaseAuth.instance.currentUser; 
                  });
                  
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Nombre actualizado correctamente')),
                  );
                }
              },
              child: const Text('Guardar'),
            ),
          ],
        );
      },
    );
  }
  
  void _mostrarDialogoCambiarClave() {
    final TextEditingController claveActualController = TextEditingController();
    final TextEditingController claveNuevaController = TextEditingController();

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Cambiar Contraseña'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: claveActualController,
              obscureText: true,
              autofocus: true,
              decoration: const InputDecoration(labelText: 'Contraseña Actual', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 15),
            TextField(
              controller: claveNuevaController,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Nueva Contraseña', border: OutlineInputBorder()),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () async {
              if (claveActualController.text.trim().isEmpty || claveNuevaController.text.trim().isEmpty) return;
              
              final scaffoldMessenger = ScaffoldMessenger.of(context);
              
              if (!_esContrasenaSegura(claveNuevaController.text)) {
                scaffoldMessenger.showSnackBar(
                  const SnackBar(content: Text('La clave debe tener 8+ caracteres, Mayús, Núm y Símbolo.'), backgroundColor: Colors.orange),
                );
                return;
              }
              
              final user = FirebaseAuth.instance.currentUser;
              if (user == null || user.email == null) return;
              final navigator = Navigator.of(dialogContext);
              
              try {
                await FirebaseAuth.instance.signInWithEmailAndPassword(
                  email: user.email!,
                  password: claveActualController.text,
                );
                await user.updatePassword(claveNuevaController.text.trim());
                navigator.pop();
                scaffoldMessenger.showSnackBar(
                  const SnackBar(content: Text('Contraseña actualizada con éxito'), backgroundColor: Colors.green),
                );
              } catch (e) {
                scaffoldMessenger.showSnackBar(
                  const SnackBar(content: Text('Error: Verifica tu contraseña actual'), backgroundColor: Colors.red),
                );
              }
            },
            child: const Text('Actualizar'),
          ),
        ],
      ),
    );
  }

  void _confirmarCerrarSesion(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('¿Cerrar sesión?'),
        content: const Text('¿Estás seguro de que deseas salir de CampusSync?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () async {
              Navigator.pop(dialogContext); 
              await google_auth.GoogleSignIn().signOut();
              await FirebaseAuth.instance.signOut();
            },
            child: const Text('Cerrar Sesión'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    bool esUsuarioGoogle = user?.providerData.any((provider) => provider.providerId == 'google.com') ?? false;

    return Scaffold(
      appBar: AppBar(title: const Text('Mi Perfil')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Center(
            child: CircleAvatar(
              radius: 60,
              backgroundImage: user?.photoURL != null ? NetworkImage(user!.photoURL!) : null,
              child: user?.photoURL == null ? const Icon(Icons.person, size: 80) : null,
            ),
          ),
          const SizedBox(height: 20),
          Center(child: Text(user?.displayName ?? 'Estudiante UA', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold))),
          Center(child: Text(user?.email ?? '', style: const TextStyle(fontSize: 16, color: Colors.grey))),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: _editarNombre,
            icon: const Icon(Icons.edit),
            label: const Text('Editar Nombre'),
          ),
          if (!esUsuarioGoogle) ...[
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: _mostrarDialogoCambiarClave,
              icon: const Icon(Icons.lock_reset),
              label: const Text('Cambiar Contraseña'),
            ),
          ],
          const SizedBox(height: 20),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade50, foregroundColor: Colors.red),
            onPressed: () => _confirmarCerrarSesion(context),
            icon: const Icon(Icons.logout),
            label: const Text('Cerrar Sesión'),
          ),
          // BOTÓN EXCLUSIVO PARA MODERADORES
          // BOTÓN PARA ADMINS Y MODERADORES
          FutureBuilder<DocumentSnapshot>(
            future: FirebaseFirestore.instance.collection('usuarios').doc(user?.uid).get(),
            builder: (context, snapshot) {
              if (snapshot.hasData && snapshot.data!.exists) {
                var datos = snapshot.data!.data() as Map<String, dynamic>;
                String rolActual = datos['rol'] ?? 'estudiante'; // Extraemos el rol de forma segura
                
                // Permitimos que TANTO el admin como el moderador vean el botón
                if (rolActual == 'moderador' || rolActual == 'admin') {
                  return Padding(
                    padding: const EdgeInsets.only(top: 20),
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blueGrey.shade900,
                        foregroundColor: Colors.white,
                      ),
                      onPressed: () {
                        Navigator.push(
                          context,
                          // AQUÍ SE SOLUCIONA EL ERROR: Pasamos la variable y quitamos el 'const'
                          MaterialPageRoute(builder: (context) => PantallaDashboard(rolUsuario: rolActual)),
                        );
                      },
                      icon: const Icon(Icons.analytics),
                      label: const Text('Panel de Administración'),
                    ),
                  );
                }
              }
              return const SizedBox.shrink(); // Si es estudiante, no muestra nada
            },
          ),
        ],
      ),
    );
  }
}