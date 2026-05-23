import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class PantallaSolicitudesCurso extends StatefulWidget {
  final Map<String, dynamic> curso;

  const PantallaSolicitudesCurso({super.key, required this.curso});

  @override
  State<PantallaSolicitudesCurso> createState() => _PantallaSolicitudesCursoState();
}

class _PantallaSolicitudesCursoState extends State<PantallaSolicitudesCurso> {
  
  Future<void> _aprobarAlumno(String estudianteId) async {
    String cursoId = widget.curso['id'];
    try {
      await FirebaseFirestore.instance
          .collection('cursos')
          .doc(cursoId)
          .collection('matriculados')
          .doc(estudianteId)
          .set({
        'estudianteId': estudianteId,
        'fechaMatricula': FieldValue.serverTimestamp(),
      });

      await FirebaseFirestore.instance
          .collection('cursos')
          .doc(cursoId)
          .collection('solicitudes')
          .doc(estudianteId)
          .delete();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Estudiante aprobado e inscrito en el curso.'), backgroundColor: Colors.green),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al aprobar: $e'), backgroundColor: Colors.red),
      );
    }
  }

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
        const SnackBar(content: Text('Solicitud rechazada.'), backgroundColor: Colors.orange),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al rechazar: $e'), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    String cursoId = widget.curso['id'];

    return Scaffold(
      appBar: AppBar(title: const Text('Solicitudes de Acceso')),
      body: StreamBuilder<QuerySnapshot>(
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
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(
              child: Text('No hay solicitudes pendientes.', style: TextStyle(color: Colors.grey, fontSize: 15)),
            );
          }

          final solicitudes = snapshot.data!.docs;

          return ListView.builder(
            itemCount: solicitudes.length,
            padding: const EdgeInsets.all(12),
            itemBuilder: (context, index) {
              String estudianteId = solicitudes[index].id;

              return FutureBuilder<DocumentSnapshot>(
                future: FirebaseFirestore.instance.collection('usuarios').doc(estudianteId).get(),
                builder: (context, userSnapshot) {
                  if (userSnapshot.connectionState == ConnectionState.waiting) {
                    return const Card(
                      margin: EdgeInsets.only(bottom: 10),
                      child: Padding(
                        padding: EdgeInsets.all(16.0),
                        child: Row(
                          children: [
                            SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
                            SizedBox(width: 15),
                            Text('Cargando datos del alumno...', style: TextStyle(color: Colors.grey)),
                          ],
                        ),
                      ),
                    );
                  }

                  // CONFIGURACIÓN DE RESPALDO PROFESIONAL
                  // Si no existe el documento en Firestore, usamos datos genéricos limpios (nunca el ID feo)
                  String nombreMostrar = 'Estudiante sin Perfil';
                  String correoMostrar = 'Cuenta por verificar';

                  if (userSnapshot.hasData && userSnapshot.data!.exists) {
                    var datosUsuario = userSnapshot.data!.data() as Map<String, dynamic>;
                    nombreMostrar = datosUsuario['nombre'] ?? 'Estudiante UA';
                    correoMostrar = datosUsuario['correo'] ?? '';
                  }

                  return Card(
                    margin: const EdgeInsets.only(bottom: 10),
                    elevation: 2,
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      leading: CircleAvatar(
                        backgroundColor: Colors.blue.shade50,
                        child: Text(
                          nombreMostrar.isNotEmpty ? nombreMostrar[0].toUpperCase() : 'E', 
                          style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.bold)
                        ),
                      ),
                      title: Text(nombreMostrar, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      // Aquí quitamos el ID. Ahora solo muestra el correo si existe, o un estado limpio.
                      subtitle: correoMostrar.isNotEmpty 
                          ? Text(correoMostrar, style: TextStyle(fontSize: 13, color: Colors.grey.shade600))
                          : null,
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.close, color: Colors.red),
                            tooltip: 'Rechazar',
                            onPressed: () => _rechazarAlumno(estudianteId),
                          ),
                          const SizedBox(width: 5),
                          IconButton(
                            icon: const Icon(Icons.check, color: Colors.green),
                            tooltip: 'Aprobar',
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