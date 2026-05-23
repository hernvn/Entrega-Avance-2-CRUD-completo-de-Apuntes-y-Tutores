import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class VistaApuntes extends StatelessWidget {
  const VistaApuntes({super.key});

  void _confirmarEliminacion(BuildContext context, String id) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('¿Eliminar apunte?'),
        content: const Text('Esta acción no se puede deshacer.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () async {
              await FirebaseFirestore.instance.collection('apuntes').doc(id).delete();
              if (context.mounted) {
                Navigator.pop(dialogContext);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Apunte eliminado'), backgroundColor: Colors.orange),
                );
              }
            },
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
  }

  void _mostrarDialogoEdicion(BuildContext context, String id, String nombreActual, String materiaActual) {
    TextEditingController nombreEdit = TextEditingController(text: nombreActual);
    TextEditingController materiaEdit = TextEditingController(text: materiaActual);

    showDialog(
      context: context,
      builder: (editContext) => AlertDialog(
        title: const Text('Editar Apunte'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nombreEdit, decoration: const InputDecoration(labelText: 'Nombre')),
            TextField(controller: materiaEdit, decoration: const InputDecoration(labelText: 'Materia')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(editContext), child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () async {
              await FirebaseFirestore.instance.collection('apuntes').doc(id).update({
                'nombre_archivo': nombreEdit.text.trim(),
                'materia': materiaEdit.text.trim(),
              });
              if (context.mounted) Navigator.pop(editContext);
            },
            child: const Text('Actualizar'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final String uidActual = FirebaseAuth.instance.currentUser?.uid ?? '';

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('apuntes')
          .orderBy('fecha_subida', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(
            child: Text('Aún no hay material subido.',
                style: TextStyle(color: Colors.grey)),
          );
        }

        final apuntes = snapshot.data!.docs;

        return ListView.builder(
          padding: const EdgeInsets.all(16.0),
          itemCount: apuntes.length,
          itemBuilder: (context, index) {
            var apunte = apuntes[index].data() as Map<String, dynamic>;
            String apunteId = apuntes[index].id;

            return Card(
              elevation: 2,
              margin: const EdgeInsets.only(bottom: 12),
              child: ListTile(
                leading: const Icon(Icons.picture_as_pdf, color: Colors.red, size: 40),
                title: Text(apunte['nombre_archivo'] ?? 'Sin título',
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text('${apunte['materia']} • Por: ${apunte['autor_nombre']}'),
                
                trailing: (uidActual == apunte['autor_id'])
                    ? Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.edit, color: Colors.blue),
                            onPressed: () => _mostrarDialogoEdicion(
                                context, 
                                apunteId, 
                                apunte['nombre_archivo'], 
                                apunte['materia']
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            onPressed: () => _confirmarEliminacion(context, apunteId),
                          ),
                        ],
                      )
                    : const Icon(Icons.download_rounded, color: Colors.grey),
              ),
            );
          },
        );
      },
    );
  }
}

class VistaTutores extends StatelessWidget {
  const VistaTutores({super.key});

  void _mostrarFormularioTutor(BuildContext context) {
    TextEditingController especialidadController = TextEditingController();
    TextEditingController descripcionController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Postular como Tutor'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: especialidadController,
              decoration: const InputDecoration(labelText: 'Especialidad (ej: Cálculo II)'),
            ),
            TextField(
              controller: descripcionController,
              decoration: const InputDecoration(labelText: 'Breve descripción'),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () async {
              final user = FirebaseAuth.instance.currentUser;
              if (user != null) {
                await FirebaseFirestore.instance.collection('tutores').add({
                  'uid': user.uid,
                  'nombre': user.displayName ?? 'Estudiante',
                  'especialidad': especialidadController.text.trim(),
                  'descripcion': descripcionController.text.trim(),
                  'fecha': FieldValue.serverTimestamp(),
                });
                
                if (!context.mounted) return;
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('¡Ya eres parte del equipo de tutores!')),
                );
              }
            },
            child: const Text('Publicar'),
          ),
        ],
      ),
    );
  }

  void _confirmarEliminacionTutor(BuildContext context, String id) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('¿Eliminar perfil de tutor?'),
        content: const Text('Tu perfil dejará de ser visible para otros estudiantes. ¿Deseas continuar?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              await FirebaseFirestore.instance.collection('tutores').doc(id).delete();
              if (context.mounted) {
                Navigator.pop(dialogContext);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Perfil de tutor eliminado'),
                    backgroundColor: Colors.orange,
                  ),
                );
              }
            },
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final String uidActual = FirebaseAuth.instance.currentUser?.uid ?? '';

    return Scaffold(
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('tutores').orderBy('fecha', descending: true).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator()); 
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('No hay tutores disponibles aún.'));
          }

          final tutores = snapshot.data!.docs;

          return ListView.builder(
            padding: const EdgeInsets.all(16.0),
            itemCount: tutores.length,
            itemBuilder: (context, index) {
              var tutor = tutores[index].data() as Map<String, dynamic>;
              String docId = tutores[index].id;

              return Card(
                elevation: 3,
                margin: const EdgeInsets.only(bottom: 15),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Colors.blue,
                    child: Text(tutor['nombre'][0].toUpperCase(), style: const TextStyle(color: Colors.white)),
                  ),
                  title: Text(tutor['nombre'], style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text('${tutor['especialidad']}\n${tutor['descripcion']}'),
                  isThreeLine: true,
                  trailing: uidActual == tutor['uid']
                      ? IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          onPressed: () => _confirmarEliminacionTutor(context, docId), 
                        )
                      : const Icon(Icons.chat_bubble_outline, color: Colors.blue),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _mostrarFormularioTutor(context),
        label: const Text('Ser Tutor'),
        icon: const Icon(Icons.add),
      ),
    );
  }
}

class VistaSubir extends StatefulWidget {
  const VistaSubir({super.key});

  @override
  State<VistaSubir> createState() => _VistaSubirState();
}

class _VistaSubirState extends State<VistaSubir> {
  final TextEditingController _nombreController = TextEditingController();
  final TextEditingController _materiaController = TextEditingController();
  bool _estaCargando = false;

  void _guardarApunte() async {
    if (_nombreController.text.trim().isEmpty || _materiaController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor, completa todos los campos.'), backgroundColor: Colors.red),
      );
      return;
    }

    setState(() => _estaCargando = true);

    try {
      final User? usuario = FirebaseAuth.instance.currentUser;
      if (usuario == null) throw Exception('Debes iniciar sesión para subir material');

      await FirebaseFirestore.instance.collection('apuntes').add({
        'nombre_archivo': _nombreController.text.trim(),
        'materia': _materiaController.text.trim(),
        'autor_id': usuario.uid,
        'autor_nombre': usuario.displayName ?? 'Estudiante',
        'fecha_subida': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('¡Material guardado exitosamente!'), backgroundColor: Colors.green),
        );
        _nombreController.clear();
        _materiaController.clear();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al guardar: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _estaCargando = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(30.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SizedBox(height: 40),
          const Icon(Icons.cloud_upload, size: 100, color: Colors.blue),
          const SizedBox(height: 40),
          TextField(
            controller: _nombreController,
            decoration: const InputDecoration(
              labelText: 'Nombre del Archivo (Ej: Guía de Área)',
              border: UnderlineInputBorder(),
            ),
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _materiaController,
            decoration: const InputDecoration(
              labelText: 'Materia (Ej: Cálculo II)',
              border: UnderlineInputBorder(),
            ),
          ),
          const SizedBox(height: 40),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue.shade50,
                foregroundColor: Colors.blue.shade700,
                elevation: 0,
              ),
              onPressed: _estaCargando ? null : _guardarApunte,
              child: _estaCargando
                  ? const SizedBox(height: 25, width: 25, child: CircularProgressIndicator()) 
                  : const Text('Guardar Material', style: TextStyle(fontSize: 16)),
            ),
          ),
        ],
      ),
    );
  }
}