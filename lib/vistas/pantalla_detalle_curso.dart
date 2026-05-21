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
  bool solicitudPendiente = false; // Controla si tiene una solicitud en espera
  bool cargandoEstado = true;

  @override
  void initState() {
    super.initState();
    _verificarAccesoYSolicitudes();
  }

  // Consulta simultáneamente si está matriculado o tiene solicitudes enviadas
  Future<void> _verificarAccesoYSolicitudes() async {
    try {
      final String? uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid != null) {
        String cursoId = widget.curso['id'];
        
        // 1. Revisar si está matriculado
        final docMatricula = await FirebaseFirestore.instance
            .collection('cursos')
            .doc(cursoId)
            .collection('matriculados')
            .doc(uid)
            .get();
        
        if (docMatricula.exists) {
          if (mounted) {
            setState(() {
              yaMatriculado = true;
              cargandoEstado = false;
            });
          }
          return;
        }

        // 2. Si no está matriculado, revisar si envió una solicitud privada
        final docSolicitud = await FirebaseFirestore.instance
            .collection('cursos')
            .doc(cursoId)
            .collection('solicitudes')
            .doc(uid)
            .get();

        if (mounted) {
          setState(() {
            solicitudPendiente = docSolicitud.exists;
            cargandoEstado = false;
          });
        }
      }
    } catch (e) {
      debugPrint('Error al verificar estados: $e');
      if (mounted) {
        setState(() {
          cargandoEstado = false;
        });
      }
    }
  }

  // Matrícula directa (Cursos Públicos)
  Future<void> _matricularseDirecto() async {
    try {
      final String? uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid != null) {
        String cursoId = widget.curso['id'];
        
        await FirebaseFirestore.instance
            .collection('cursos')
            .doc(cursoId)
            .collection('matriculados')
            .doc(uid)
            .set({
          'estudianteId': uid,
          'fechaMatricula': FieldValue.serverTimestamp(),
        });

        if (mounted) {
          setState(() {
            yaMatriculado = true;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('¡Te has matriculado con éxito!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al matricularse: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  // Envío de Solicitud (Cursos Privados)
  Future<void> _solicitarAcceso() async {
    try {
      final String? uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid != null) {
        String cursoId = widget.curso['id'];
        
        await FirebaseFirestore.instance
            .collection('cursos')
            .doc(cursoId)
            .collection('solicitudes')
            .doc(uid)
            .set({
          'estudianteId': uid,
          'fechaSolicitud': FieldValue.serverTimestamp(),
          'estado': 'pendiente',
        });

        if (mounted) {
          setState(() {
            solicitudPendiente = true;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Solicitud de acceso enviada al creador del curso.'),
              backgroundColor: Colors.blue,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al enviar solicitud: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _seleccionarPDF() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );

    if (result != null && result.files.single.path != null) {
      String nombreArchivo = result.files.single.name;
      String rutaArchivo = result.files.single.path!;
      File archivoFisico = File(rutaArchivo);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Subiendo $nombreArchivo... Espere un momento.')),
      );

      try {
        String cursoId = widget.curso['id'];
        Reference ref = FirebaseStorage.instance
            .ref()
            .child('cursos/$cursoId/materiales/$nombreArchivo');
        
        UploadTask uploadTask = ref.putFile(archivoFisico);
        TaskSnapshot snapshot = await uploadTask;
        
        String urlDescarga = await snapshot.ref.getDownloadURL();

        await FirebaseFirestore.instance
            .collection('cursos')
            .doc(cursoId)
            .collection('materiales')
            .add({
          'nombre': nombreArchivo,
          'url': urlDescarga,
          'fechaSubida': FieldValue.serverTimestamp(),
        });

        if (!mounted) return;
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('¡Material subido y guardado con éxito!'),
            backgroundColor: Colors.green,
          ),
        );

      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al subir el documento: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _eliminarPDF(String materialId, String urlArchivo, String nombreArchivo) async {
    try {
      Reference storageRef = FirebaseStorage.instance.refFromURL(urlArchivo);
      await storageRef.delete();

      String cursoId = widget.curso['id'];
      await FirebaseFirestore.instance
          .collection('cursos')
          .doc(cursoId)
          .collection('materiales')
          .doc(materialId)
          .delete();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('"$nombreArchivo" fue eliminado correctamente.'),
          backgroundColor: Colors.orange,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al intentar eliminar: $e'), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final String? usuarioActualId = FirebaseAuth.instance.currentUser?.uid;
    final String creadorCursoId = widget.curso['creadorId'] ?? '';
    final bool esCreador = usuarioActualId == creadorCursoId;

    final bool tieneAcceso = esCreador || yaMatriculado;
    final bool esCursoPrivado = widget.curso['visibilidad'] == 'privado';

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.curso['titulo'] ?? 'Detalle del Curso'),
        actions: [
          // Si el usuario es el creador del curso y este es privado, se muestra el ícono de revisión
          if (esCreador && esCursoPrivado)
            IconButton(
              icon: const Icon(Icons.assignment_ind_outlined),
              tooltip: 'Solicitudes Pendientes',
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => PantallaSolicitudesCurso(curso: widget.curso),
                  ),
                );
              },
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
                  // Encabezado informativo
                  Row(
                    children: [
                      Chip(
                        label: Text(
                          widget.curso['visibilidad'].toString().toUpperCase(),
                          style: const TextStyle(color: Colors.white, fontSize: 12),
                        ),
                        backgroundColor: esCursoPrivado ? Colors.orange : Colors.green,
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'ID: ${widget.curso['id']}',
                        style: const TextStyle(color: Colors.grey),
                      ),
                    ],
                  ),
                  const SizedBox(height: 15),
                  
                  // SECCIÓN DE LA DESCRIPCIÓN (Visible para todos)
                  const Text(
                    'Acerca de este curso:',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.grey),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    widget.curso['descripcion'] ?? 'Sin descripción disponible.',
                    style: const TextStyle(fontSize: 15, color: Colors.black87, height: 1.3),
                  ),
                  const Divider(height: 30, thickness: 1),

                  // CASO 1: NO TIENE ACCESO AL MATERIAL
                  if (!tieneAcceso) ...[
                    if (solicitudPendiente) ...[
                      const Expanded(
                        child: Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.hourglass_top, size: 48, color: Colors.orange),
                              SizedBox(height: 12),
                              Text(
                                'Solicitud Pendiente',
                                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.orange),
                              ),
                              SizedBox(height: 6),
                              Text(
                                'El creador de la ayudantía debe aprobar tu acceso para que puedas ver y descargar los archivos.',
                                textAlign: TextAlign.center,
                                style: TextStyle(color: Colors.grey, fontSize: 14),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ] else ...[
                      Expanded(
                        child: Center(
                          child: Text(
                            esCursoPrivado
                                ? 'Esta ayudantía es privada. Solicita acceso para poder revisar los archivos cargados.'
                                : 'No estás inscrito en este módulo académico todavía.',
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontSize: 15, color: Colors.grey),
          ),
                        ),
                      ),
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton.icon(
                          // Decide si matricula directo o crea flujo de solicitud
                          onPressed: esCursoPrivado ? _solicitarAcceso : _matricularseDirecto,
                          icon: Icon(esCursoPrivado ? Icons.lock_open : Icons.group_add),
                          label: Text(esCursoPrivado ? 'Solicitar Acceso al Curso' : 'Matricularse en el Curso'),
                        ),
                      ),
                    ],
                  ],

                  // CASO 2: TIENE ACCESO (Creador o Alumno Aprobado)
                  if (tieneAcceso) ...[
                    const Text(
                      'Material de Estudio (PDFs)',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 10),
                    Expanded(
                      child: StreamBuilder<QuerySnapshot>(
                        stream: FirebaseFirestore.instance
                            .collection('cursos')
                            .doc(widget.curso['id'])
                            .collection('materiales')
                            .orderBy('fechaSubida', descending: true)
                            .snapshots(),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState == ConnectionState.waiting) {
                            return const Center(child: CircularProgressIndicator());
                          }
                          if (snapshot.hasError) {
                            return Center(child: Text('Error al cargar el material: ${snapshot.error}'));
                          }
                          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                            return const Center(child: Text('Aún no hay material de apoyo para esta ayudantía.'));
                          }

                          final materiales = snapshot.data!.docs;

                          return ListView.builder(
                            itemCount: materiales.length,
                            itemBuilder: (context, index) {
                              var doc = materiales[index];
                              var material = doc.data() as Map<String, dynamic>;
                              
                              String materialId = doc.id;
                              String nombreArchivo = material['nombre'] ?? 'Archivo sin nombre';
                              String url = material['url'] ?? '';

                              return Card(
                                margin: const EdgeInsets.only(bottom: 8),
                                child: ListTile(
                                  leading: const Icon(Icons.picture_as_pdf, color: Colors.red),
                                  title: Text(nombreArchivo),
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        icon: const Icon(Icons.download, color: Colors.blue),
                                        onPressed: () async {
                                          final Uri fileUrl = Uri.parse(url);
                                          try {
                                            await launchUrl(fileUrl, mode: LaunchMode.externalApplication);
                                          } catch (e) {
                                            if (!context.mounted) return;
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              const SnackBar(content: Text('Error al abrir el navegador.')),
                                            );
                                          }
                                        },
                                      ),
                                      if (esCreador)
                                        IconButton(
                                          icon: const Icon(Icons.delete, color: Colors.red),
                                          onPressed: () {
                                            _eliminarPDF(materialId, url, nombreArchivo);
                                          },
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
                    
                    if (esCreador) ...[
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue.shade50,
                            foregroundColor: Colors.blue.shade800,
                          ),
                          onPressed: _seleccionarPDF,
                          icon: const Icon(Icons.upload_file),
                          label: const Text('Subir Archivo PDF'),
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