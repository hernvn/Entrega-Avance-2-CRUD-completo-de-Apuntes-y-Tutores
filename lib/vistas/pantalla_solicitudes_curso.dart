import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class PantallaSolicitudesCurso extends StatefulWidget {
  final Map<String, dynamic> curso;

  const PantallaSolicitudesCurso({super.key, required this.curso});

  @override
  State<PantallaSolicitudesCurso> createState() => _PantallaSolicitudesCursoState();
}

class _PantallaSolicitudesCursoState extends State<PantallaSolicitudesCurso> {
  
  // Mueve al alumno a la colección de aprobados (matriculados) y elimina su solicitud
  Future<void> _aprobarAlumno(String estudianteId) async {
    String cursoId = widget.curso['id'];

    try {
      // 1. Registrar el UID del estudiante en la subcolección 'matriculados'
      await FirebaseFirestore.instance
          .collection('cursos')
          .doc(cursoId)
          .collection('matriculados')
          .doc(estudianteId)
          .set({
        'estudianteId': estudianteId,
        'fechaMatricula': FieldValue.serverTimestamp(),
      });

      // 2. Borrar la solicitud pendiente para sacarlo de la lista de espera
      await FirebaseFirestore.instance
          .collection('cursos')
          .doc(cursoId)
          .collection('solicitudes')
          .doc(estudianteId)
          .delete();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Estudiante aprobado y inscrito en el curso.'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al aprobar al estudiante: $e'), backgroundColor: Colors.red),
      );
    }
  }

  // Descarta la solicitud eliminándola de la subcolección
  Future<void> _rechazarAlumno(String estudianteId) async {
    String cursoId = widget.curso['id'];

    try {
      await FirebaseFirestore.instance
          .collection('cursos')
          .doc(cursoId)
          .collection('solicitudes')
          .doc(estudianteId)
          .delete();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Solicitud de acceso rechazada.'),
          backgroundColor: Colors.orange,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al rechazar la solicitud: $e'), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    String cursoId = widget.curso['id'];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Solicitudes de Acceso'),
      ),
      body: StreamBuilder<QuerySnapshot>(
        // Escuchamos en tiempo real las solicitudes que entren a este curso
        stream: FirebaseFirestore.instance
            .collection('cursos')
            .doc(cursoId)
            .collection('solicitudes')
            .orderBy('fechaSolicitud', descending: false)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error al cargar la lista de espera: ${snapshot.error}'));
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(
              child: Text(
                'No hay solicitudes pendientes en este momento.',
                style: TextStyle(color: Colors.grey, fontSize: 15),
              ),
            );
          }

          final solicitudes = snapshot.data!.docs;

          return ListView.builder(
            itemCount: solicitudes.length,
            padding: const EdgeInsets.all(12),
            itemBuilder: (context, index) {
              var doc = solicitudes[index];
              String estudianteId = doc.id; // El UID de Firebase Auth

              // Usamos FutureBuilder para transformar el ID en un Nombre Real
              return FutureBuilder<DocumentSnapshot>(
                future: FirebaseFirestore.instance.collection('usuarios').doc(estudianteId).get(),
                builder: (context, userSnapshot) {
                  String nombreMostrar = 'Cargando nombre...';
                  String correoMostrar = 'Cargando correo...';

                  if (userSnapshot.hasData && userSnapshot.data!.exists) {
                    var datosUsuario = userSnapshot.data!.data() as Map<String, dynamic>;
                    nombreMostrar = datosUsuario['nombre'] ?? 'Usuario sin nombre';
                    correoMostrar = datosUsuario['correo'] ?? '';
                  }

                  return Card(
                    margin: const EdgeInsets.only(bottom: 10),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      leading: CircleAvatar(
                        backgroundColor: Colors.blue.shade50,
                        child: const Icon(Icons.person, color: Colors.blue),
                      ),
                      title: Text(
                        nombreMostrar,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      subtitle: Text(
                        correoMostrar.isNotEmpty ? correoMostrar : 'ID: $estudianteId',
                        style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.close, color: Colors.red),
                            tooltip: 'Rechazar Acceso',
                            onPressed: () => _rechazarAlumno(estudianteId),
                          ),
                          const SizedBox(width: 5),
                          IconButton(
                            icon: const Icon(Icons.check, color: Colors.green),
                            tooltip: 'Aprobar Acceso',
                            onPressed: () => _aprobarAlumno(estudianteId),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}