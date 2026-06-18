import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart'; // <-- Para saber quién es el Admin actual

class PantallaGestionUsuarios extends StatelessWidget {
  const PantallaGestionUsuarios({super.key});

  Future<void> _actualizarRol(String id, String nuevoRol, BuildContext context) async {
    try {
      await FirebaseFirestore.instance.collection('usuarios').doc(id).update({
        'rol': nuevoRol,
      });

      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Rol actualizado a $nuevoRol exitosamente.'),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al actualizar: $e'), backgroundColor: Colors.red),
      );
    }
  }

  // NUEVO: Cuadro de diálogo de confirmación
  Future<void> _confirmarCambioRol(BuildContext context, String id, String nombre, String rolActual, String nuevoRol) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Confirmar Cambio', style: TextStyle(fontWeight: FontWeight.bold)),
          content: Text('¿Estás seguro de que deseas cambiar el rol de "$nombre" de $rolActual a $nuevoRol?'),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancelar', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.blue.shade800, foregroundColor: Colors.white),
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Sí, cambiar rol'),
            ),
          ],
        );
      },
    );

    // Si el usuario presionó "Sí, cambiar rol"
    if (confirmar == true && context.mounted) {
      await _actualizarRol(id, nuevoRol, context);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Obtenemos el ID del administrador que está usando la pantalla
    final String currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Gestión de Usuarios', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.blue.shade800,
        foregroundColor: Colors.white,
      ),
      backgroundColor: Colors.grey.shade100,
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('usuarios').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('No hay usuarios registrados.'));
          }

          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: snapshot.data!.docs.length,
            itemBuilder: (context, index) {
              var usuario = snapshot.data!.docs[index];
              String id = usuario.id;
              Map<String, dynamic> data = usuario.data() as Map<String, dynamic>;
              
              String nombre = data['nombre'] ?? 'Sin nombre';
              String correo = data['correo'] ?? 'Sin correo';
              String rolActual = data['rol'] ?? 'estudiante';

              // VERIFICACIÓN CLAVE: ¿Este usuario soy yo mismo?
              bool soyYoMismo = id == currentUserId;

              return Card(
                margin: const EdgeInsets.symmetric(vertical: 8),
                elevation: 2,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  leading: CircleAvatar(
                    backgroundColor: soyYoMismo ? Colors.blue.shade900 : Colors.blue.shade100,
                    child: Icon(
                      soyYoMismo ? Icons.admin_panel_settings : Icons.person, 
                      color: soyYoMismo ? Colors.white : Colors.blue
                    ),
                  ),
                  title: Text(soyYoMismo ? '$nombre (Tú)' : nombre, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text('$correo\nRol actual: $rolActual'),
                  isThreeLine: true,
                  
                  // Si soy yo mismo, muestro un candado. Si es otro, muestro el menú desplegable.
                  trailing: soyYoMismo
                      ? const Chip(
                          label: Text('Protegido', style: TextStyle(color: Colors.white, fontSize: 12)),
                          backgroundColor: Colors.grey,
                          avatar: Icon(Icons.lock, color: Colors.white, size: 16),
                        )
                      : DropdownButton<String>(
                          value: ['estudiante', 'moderador', 'admin'].contains(rolActual) ? rolActual : 'estudiante',
                          underline: Container(height: 2, color: Colors.blue.shade200), 
                          items: const [
                            DropdownMenuItem(value: 'estudiante', child: Text('Estudiante')),
                            DropdownMenuItem(value: 'moderador', child: Text('Moderador')),
                            DropdownMenuItem(value: 'admin', child: Text('Admin', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold))),
                          ],
                          onChanged: (String? nuevoRol) {
                            if (nuevoRol != null && nuevoRol != rolActual) {
                              // Llamamos a la función de confirmación en lugar de actualizar directo
                              _confirmarCambioRol(context, id, nombre, rolActual, nuevoRol);
                            }
                          },
                        ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}