import 'pantalla_solicitudes_curso.dart';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:firebase_auth/firebase_auth.dart';

class PantallaDetalleCurso extends StatefulWidget {
  final Map<String, dynamic> curso;

  const PantallaDetalleCurso({super.key, required this.curso});

  @override
  State<PantallaDetalleCurso> createState() => _PantallaDetalleCursoState();
}

class _PantallaDetalleCursoState extends State<PantallaDetalleCurso> {
  bool yaMatriculado = false;
  bool solicitudPendiente = false; 
  bool esCreador = false;
  bool esModerador = false;
  bool tieneAcceso = false;
  bool cargandoEstado = true;
  String nombreCreador = "Cargando creador...";

  @override
  void initState() {
    super.initState();
    _cargarDatosYPermisos();
  }

  Future<void> _cargarDatosYPermisos() async {
    try {
      final String? uid = FirebaseAuth.instance.currentUser?.uid;
      String cursoId = widget.curso['id'];
      String creadorId = widget.curso['creadorId'] ?? '';

      // 1. Obtener el nombre real del Creador del curso
      if (creadorId.isNotEmpty) {
        var creadorDoc = await FirebaseFirestore.instance.collection('usuarios').doc(creadorId).get();
        if (mounted) {
          setState(() {
            if (creadorDoc.exists) {
              nombreCreador = creadorDoc.data()?['nombre'] ?? 'Profesor sin nombre';
            } else {
              nombreCreador = 'Profesor (ID: $creadorId)'; // Respaldo si no existe en Firestore
            }
          });
        }
      }

      if (uid != null) {
        // 2. Verificar si es el creador
        if (uid == creadorId) {
          esCreador = true;
          tieneAcceso = true;
        } else {
          // 3. Verificar si el usuario actual es un Moderador Global
          var miPerfilDoc = await FirebaseFirestore.instance.collection('usuarios').doc(uid).get();
          if (miPerfilDoc.exists && miPerfilDoc.data()?['rol'] == 'moderador') {
            esModerador = true;
            tieneAcceso = true;
          }
        }

        // 4. Si no es creador ni moderador, revisar su matrícula o solicitud
        if (!tieneAcceso) {
          final docMatricula = await FirebaseFirestore.instance
              .collection('cursos').doc(cursoId).collection('matriculados').doc(uid).get();
          
          if (docMatricula.exists) {
            yaMatriculado = true;
            tieneAcceso = true;
          } else {
            final docSolicitud = await FirebaseFirestore.instance
                .collection('cursos').doc(cursoId).collection('solicitudes').doc(uid).get();
            solicitudPendiente = docSolicitud.exists;
          }
        }
      }
    } catch (e) {
      debugPrint('Error al verificar permisos: $e');
    } finally {
      if (mounted) setState(() => cargandoEstado = false);
    }
  }

  Future<void> _matricularseDirecto() async {
    final String? uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    try {
      await FirebaseFirestore.instance
          .collection('cursos').doc(widget.curso['id']).collection('matriculados').doc(uid)
          .set({'estudianteId': uid, 'fechaMatricula': FieldValue.serverTimestamp()});
      if (mounted) {
        setState(() { yaMatriculado = true; tieneAcceso = true; });
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('¡Te has matriculado con éxito!'), backgroundColor: Colors.green));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
    }
  }

  Future<void> _solicitarAcceso() async {
    final String? uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    try {
      await FirebaseFirestore.instance
          .collection('cursos').doc(widget.curso['id']).collection('solicitudes').doc(uid)
          .set({'estudianteId': uid, 'fechaSolicitud': FieldValue.serverTimestamp(), 'estado': 'pendiente'});
      if (mounted) {
        setState(() => solicitudPendiente = true);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Solicitud enviada al profesor.'), backgroundColor: Colors.blue));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
    }
  }

  Future<void> _seleccionarPDF() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['pdf']);
    if (result != null && result.files.single.path != null) {
      String nombreArchivo = result.files.single.name;
      File archivoFisico = File(result.files.single.path!);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Subiendo $nombreArchivo...')));

      try {
        String cursoId = widget.curso['id'];
        Reference ref = FirebaseStorage.instance.ref().child('cursos/$cursoId/materiales/$nombreArchivo');
        UploadTask uploadTask = ref.putFile(archivoFisico);
        TaskSnapshot snapshot = await uploadTask;
        String urlDescarga = await snapshot.ref.getDownloadURL();

        await FirebaseFirestore.instance.collection('cursos').doc(cursoId).collection('materiales').add({
          'nombre': nombreArchivo,
          'url': urlDescarga,
          'fechaSubida': FieldValue.serverTimestamp(),
          'subidoPor': FirebaseAuth.instance.currentUser?.uid,
        });

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Material subido con éxito'), backgroundColor: Colors.green));
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error al subir: $e'), backgroundColor: Colors.red));
      }
    }
  }

  Future<void> _eliminarPDF(String materialId, String urlArchivo, String nombreArchivo) async {
    try {
      await FirebaseStorage.instance.refFromURL(urlArchivo).delete();
      await FirebaseFirestore.instance.collection('cursos').doc(widget.curso['id']).collection('materiales').doc(materialId).delete();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('"$nombreArchivo" eliminado.'), backgroundColor: Colors.orange));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error al eliminar: $e'), backgroundColor: Colors.red));
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool esCursoPrivado = widget.curso['visibilidad'] == 'privado';

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.curso['titulo'] ?? 'Detalle del Curso'),
        actions: [
          // Los moderadores o el creador pueden ver las solicitudes si el curso es privado
          if ((esCreador || esModerador) && esCursoPrivado)
            IconButton(
              icon: const Icon(Icons.assignment_ind_outlined),
              tooltip: 'Ver Solicitudes',
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => PantallaSolicitudesCurso(curso: widget.curso)),
              ),
            ),
        ],
      ),
      body: cargandoEstado
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Chip(
                        label: Text(widget.curso['visibilidad'].toString().toUpperCase(), style: const TextStyle(color: Colors.white, fontSize: 12)),
                        backgroundColor: esCursoPrivado ? Colors.orange : Colors.green,
                      ),
                      const Spacer(),
                      if (esModerador) 
                        const Chip(label: Text('Vista Moderador', style: TextStyle(color: Colors.white, fontSize: 11)), backgroundColor: Colors.blueGrey),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text('Dictado por: $nombreCreador', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.blue)),
                  const SizedBox(height: 10),
                  const Text('Acerca de este curso:', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.grey)),
                  const SizedBox(height: 5),
                  Text(widget.curso['descripcion'] ?? 'Sin descripción', style: const TextStyle(fontSize: 15, height: 1.3)),
                  const Divider(height: 30, thickness: 1),

                  if (!tieneAcceso) ...[
                    if (solicitudPendiente) ...[
                      const Expanded(
                        child: Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.hourglass_top, size: 48, color: Colors.orange),
                              SizedBox(height: 12),
                              Text('Solicitud Pendiente', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.orange)),
                              SizedBox(height: 6),
                              Text('El profesor debe aprobar tu acceso para ver el material.', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)),
                            ],
                          ),
                        ),
                      ),
                    ] else ...[
                      Expanded(
                        child: Center(
                          child: Text(
                            esCursoPrivado ? 'Curso privado. Solicita acceso para ver el material.' : 'No estás matriculado en este curso.',
                            textAlign: TextAlign.center, style: const TextStyle(fontSize: 15, color: Colors.grey),
                          ),
                        ),
                      ),
                      SizedBox(
                        width: double.infinity, height: 50,
                        child: ElevatedButton.icon(
                          onPressed: esCursoPrivado ? _solicitarAcceso : _matricularseDirecto,
                          icon: Icon(esCursoPrivado ? Icons.lock_open : Icons.group_add),
                          label: Text(esCursoPrivado ? 'Solicitar Acceso' : 'Matricularse'),
                        ),
                      ),
                    ],
                  ],

                  if (tieneAcceso) ...[
                    const Text('Material de Estudio', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 10),
                    Expanded(
                      child: StreamBuilder<QuerySnapshot>(
                        stream: FirebaseFirestore.instance.collection('cursos').doc(widget.curso['id']).collection('materiales').orderBy('fechaSubida', descending: true).snapshots(),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
                          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) return const Center(child: Text('No hay material subido aún.', style: TextStyle(color: Colors.grey)));

                          final materiales = snapshot.data!.docs;

                          return ListView.builder(
                            itemCount: materiales.length,
                            itemBuilder: (context, index) {
                              var doc = materiales[index];
                              var material = doc.data() as Map<String, dynamic>;
                              String materialId = doc.id;
                              String nombreArchivo = material['nombre'] ?? 'Archivo';
                              String url = material['url'] ?? '';

                              return Card(
                                margin: const EdgeInsets.only(bottom: 8),
                                child: ListTile(
                                  leading: const Icon(Icons.picture_as_pdf, color: Colors.red, size: 30),
                                  title: Text(nombreArchivo, style: const TextStyle(fontWeight: FontWeight.w500)),
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        icon: const Icon(Icons.download, color: Colors.blue),
                                        onPressed: () async => await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication),
                                      ),
                                      // El creador o el moderador pueden eliminar material
                                      if (esCreador || esModerador)
                                        IconButton(
                                          icon: const Icon(Icons.delete, color: Colors.red),
                                          onPressed: () => _eliminarPDF(materialId, url, nombreArchivo),
                                        ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          );
                        },
                      ),
                    ),
                    if (esCreador || esModerador) ...[
                      const SizedBox(height: 15),
                      SizedBox(
                        width: double.infinity, height: 50,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.blue.shade50, foregroundColor: Colors.blue.shade800),
                          onPressed: _seleccionarPDF, icon: const Icon(Icons.upload_file), label: const Text('Subir Archivo PDF'),
                        ),
                      ),
                    ],
                  ],
                ],
              ),
            ),
    );
  }
}