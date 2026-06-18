import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:url_launcher/url_launcher.dart';
import 'pantalla_asistente.dart'; // <-- Importación del Asistente IA

class VistaApuntes extends StatefulWidget {
  const VistaApuntes({super.key});

  @override
  State<VistaApuntes> createState() => _VistaApuntesState();
}

class _VistaApuntesState extends State<VistaApuntes> {
  String _textoBusqueda = "";

  void _confirmarEliminacion(BuildContext context, String id, String? url) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('¿Eliminar apunte?', style: TextStyle(color: Colors.red)),
        content: const Text('Esta acción eliminará el archivo de la base de datos para todos los usuarios. No se puede deshacer.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () async {
              try {
                if (url != null && url.isNotEmpty) {
                  await FirebaseStorage.instance.refFromURL(url).delete();
                }
                await FirebaseFirestore.instance.collection('apuntes').doc(id).delete();
                
                if (context.mounted) {
                  Navigator.pop(dialogContext);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Apunte eliminado del sistema'), backgroundColor: Colors.orange),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error al eliminar: $e'), backgroundColor: Colors.red),
                  );
                }
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

  void _mostrarDialogoReporte(BuildContext context, String apunteId, String nombreArchivo) {
    TextEditingController motivoController = TextEditingController();
    bool enviando = false;

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setStateDialog) {
          return AlertDialog(
            title: const Text('Reportar Material', style: TextStyle(color: Colors.orange)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('¿Por qué consideras que este material debe ser revisado por un moderador?', style: TextStyle(fontSize: 13)),
                const SizedBox(height: 10),
                TextField(
                  controller: motivoController,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    hintText: 'Ej: Contenido inapropiado, no corresponde a la materia, archivo dañado...',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: enviando ? null : () => Navigator.pop(dialogContext),
                child: const Text('Cancelar'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.orange, foregroundColor: Colors.white),
                onPressed: enviando ? null : () async {
                  if (motivoController.text.trim().isEmpty) return;
                  
                  setStateDialog(() => enviando = true);
                  
                  try {
                    final String uidActual = FirebaseAuth.instance.currentUser?.uid ?? 'desconocido';
                    
                    await FirebaseFirestore.instance.collection('reportes').add({
                      'apunteId': apunteId,
                      'nombreArchivo': nombreArchivo,
                      'motivo': motivoController.text.trim(),
                      'reportadoPor': uidActual,
                      'fechaReporte': FieldValue.serverTimestamp(),
                      'estado': 'pendiente',
                    });

                    if (context.mounted) {
                      Navigator.pop(dialogContext);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Reporte enviado a los moderadores. ¡Gracias!'), backgroundColor: Colors.green),
                      );
                    }
                  } catch (e) {
                    setStateDialog(() => enviando = false);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Error al reportar: $e'), backgroundColor: Colors.red),
                      );
                    }
                  }
                },
                child: enviando 
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Text('Enviar Reporte'),
              ),
            ],
          );
        }
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final String uidActual = FirebaseAuth.instance.currentUser?.uid ?? '';

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: TextField(
            onChanged: (valor) {
              setState(() {
                _textoBusqueda = valor.toLowerCase();
              });
            },
            decoration: InputDecoration(
              hintText: 'Buscar por materia o nombre...',
              prefixIcon: const Icon(Icons.search, color: Colors.blue),
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(vertical: 0),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(30),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(30),
                borderSide: BorderSide(color: Colors.grey.shade300, width: 1),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(30),
                borderSide: const BorderSide(color: Colors.blue, width: 2),
              ),
            ),
          ),
        ),
        Expanded(
          child: FutureBuilder<DocumentSnapshot>(
            future: FirebaseFirestore.instance.collection('usuarios').doc(uidActual).get(),
            builder: (context, userSnapshot) {
              bool esModerador = false;
              
              if (userSnapshot.hasData && userSnapshot.data!.exists) {
                var datosUsuario = userSnapshot.data!.data() as Map<String, dynamic>;
                esModerador = datosUsuario['rol'] == 'moderador';
              }

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
                      child: Text('Aún no hay material subido.', style: TextStyle(color: Colors.grey)),
                    );
                  }

                  final apuntesFiltrados = snapshot.data!.docs.where((doc) {
                    var data = doc.data() as Map<String, dynamic>;
                    if (data['visible'] == false) return false;

                    String nombreArchivo = (data['nombre_archivo'] ?? '').toString().toLowerCase();
                    String materia = (data['materia'] ?? '').toString().toLowerCase();
                    
                    if (_textoBusqueda.isEmpty) return true;
                    return nombreArchivo.contains(_textoBusqueda) || materia.contains(_textoBusqueda);
                  }).toList();

                  if (apuntesFiltrados.isEmpty) {
                    return const Center(
                      child: Text('No se encontraron resultados.', style: TextStyle(color: Colors.grey)),
                    );
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    itemCount: apuntesFiltrados.length,
                    itemBuilder: (context, index) {
                      var apunte = apuntesFiltrados[index].data() as Map<String, dynamic>;
                      String apunteId = apuntesFiltrados[index].id;
                      String urlDescarga = apunte['url'] ?? '';
                      bool esAutor = uidActual == apunte['autor_id'];

                      return Card(
                        elevation: 2,
                        margin: const EdgeInsets.only(bottom: 12),
                        child: ListTile(
                          leading: const Icon(Icons.picture_as_pdf, color: Colors.red, size: 40),
                          title: Text(apunte['nombre_archivo'] ?? 'Sin título', style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Text('${apunte['materia']} • Por: ${apunte['autor_nombre']}'),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.download_rounded, color: Colors.blue),
                                tooltip: 'Descargar',
                                onPressed: () async {
                                  if (urlDescarga.isNotEmpty) {
                                    await launchUrl(Uri.parse(urlDescarga), mode: LaunchMode.externalApplication);
                                  } else {
                                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Archivo no disponible')));
                                  }
                                },
                              ),
                              if (esAutor)
                                IconButton(
                                  icon: const Icon(Icons.edit, color: Colors.orange),
                                  tooltip: 'Editar',
                                  onPressed: () => _mostrarDialogoEdicion(context, apunteId, apunte['nombre_archivo'], apunte['materia']),
                                ),
                              if (esAutor || esModerador)
                                IconButton(
                                  icon: const Icon(Icons.delete, color: Colors.red),
                                  tooltip: esModerador && !esAutor ? 'Eliminar (Como Moderador)' : 'Eliminar',
                                  onPressed: () => _confirmarEliminacion(context, apunteId, urlDescarga),
                                ),
                              if (!esAutor)
                                IconButton(
                                  icon: const Icon(Icons.flag_outlined, color: Colors.orange),
                                  tooltip: 'Reportar material',
                                  onPressed: () => _mostrarDialogoReporte(context, apunteId, apunte['nombre_archivo']),
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
        ),
      ],
    );
  }
}

class VistaTutores extends StatefulWidget {
  const VistaTutores({super.key});

  @override
  State<VistaTutores> createState() => _VistaTutoresState();
}

class _VistaTutoresState extends State<VistaTutores> {
  String _textoBusqueda = "";

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
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              onChanged: (valor) {
                setState(() {
                  _textoBusqueda = valor.toLowerCase();
                });
              },
              decoration: InputDecoration(
                hintText: 'Buscar por nombre, materia o detalle...',
                prefixIcon: const Icon(Icons.search, color: Colors.blue),
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30),
                  borderSide: BorderSide(color: Colors.grey.shade300, width: 1),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30),
                  borderSide: const BorderSide(color: Colors.blue, width: 2),
                ),
              ),
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('tutores').orderBy('fecha', descending: true).snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator()); 
                }
                
                List<DocumentSnapshot> tutoresFiltrados = [];
                if (snapshot.hasData && snapshot.data!.docs.isNotEmpty) {
                  tutoresFiltrados = snapshot.data!.docs.where((doc) {
                    var data = doc.data() as Map<String, dynamic>;
                    String nombre = (data['nombre'] ?? '').toString().toLowerCase();
                    String especialidad = (data['especialidad'] ?? '').toString().toLowerCase();
                    String descripcion = (data['descripcion'] ?? '').toString().toLowerCase();
                    
                    if (_textoBusqueda.isEmpty) return true;
                    return nombre.contains(_textoBusqueda) || 
                           especialidad.contains(_textoBusqueda) || 
                           descripcion.contains(_textoBusqueda);
                  }).toList();
                }

                // AQUÍ INTEGRAMOS AL ASISTENTE VIRTUAL DE FORMA SEGURA
                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  itemCount: tutoresFiltrados.length + 1, // +1 para el Tutor IA
                  itemBuilder: (context, index) {
                    if (index == 0) {
                      return Card(
                        elevation: 4,
                        margin: const EdgeInsets.only(bottom: 20, top: 10),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15),
                          side: BorderSide(color: Colors.blue.shade300, width: 2),
                        ),
                        child: ListTile(
                          contentPadding: const EdgeInsets.all(16),
                          leading: const CircleAvatar(
                            backgroundColor: Colors.blue,
                            radius: 25,
                            child: Icon(Icons.smart_toy, color: Colors.white, size: 30),
                          ),
                          title: const Text('Tutor IA CampusSync', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.blue)),
                          subtitle: const Padding(
                            padding: EdgeInsets.only(top: 8.0),
                            child: Text('Disponible 24/7 para resolver tus dudas :)'),
                          ),
                          trailing: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue.shade800,
                              foregroundColor: Colors.white,
                            ),
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (context) => const PantallaAsistente()),
                              );
                            },
                            child: const Text('Chatear'),
                          ),
                        ),
                      );
                    }

                    // Para el resto de los elementos, restamos 1 al índice para compensar al Tutor IA
                    var tutor = tutoresFiltrados[index - 1].data() as Map<String, dynamic>;
                    String docId = tutoresFiltrados[index - 1].id;

                    return Card(
                      elevation: 3,
                      margin: const EdgeInsets.only(bottom: 15),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Colors.blueGrey,
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
          ),
        ],
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
  File? _archivoFisico;
  String? _nombreArchivoOriginal;
  bool _abriendoBuscador = false;

  Future<void> _seleccionarPDF() async {
    if (_abriendoBuscador) return; 

    setState(() {
      _abriendoBuscador = true; 
    });

    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom, 
        allowedExtensions: ['pdf']
      );
      
      if (result != null && result.files.single.path != null) {
        setState(() {
          _archivoFisico = File(result.files.single.path!);
          _nombreArchivoOriginal = result.files.single.name;
          if (_nombreController.text.isEmpty) {
            _nombreController.text = _nombreArchivoOriginal!.replaceAll('.pdf', '');
          }
        });
      }
    } catch (e) {
      debugPrint("Error al abrir el buscador de archivos: $e");
    } finally {
      if (mounted) {
        setState(() {
          _abriendoBuscador = false; 
        });
      }
    }
  }

  void _guardarApunte() async {
    if (_nombreController.text.trim().isEmpty || _materiaController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Completa todos los campos.'), backgroundColor: Colors.red),
      );
      return;
    }

    if (_archivoFisico == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Debes seleccionar un archivo PDF.'), backgroundColor: Colors.orange),
      );
      return;
    }

    setState(() => _estaCargando = true);

    try {
      final User? usuario = FirebaseAuth.instance.currentUser;
      if (usuario == null) throw Exception('Debes iniciar sesión para subir material');

      String timestamp = DateTime.now().millisecondsSinceEpoch.toString();
      Reference ref = FirebaseStorage.instance.ref().child('apuntes_globales/${timestamp}_$_nombreArchivoOriginal');
      UploadTask uploadTask = ref.putFile(_archivoFisico!);
      TaskSnapshot snapshot = await uploadTask;
      String urlDescarga = await snapshot.ref.getDownloadURL();

      await FirebaseFirestore.instance.collection('apuntes').add({
        'nombre_archivo': _nombreController.text.trim(),
        'materia': _materiaController.text.trim(),
        'url': urlDescarga, 
        'autor_id': usuario.uid,
        'autor_nombre': usuario.displayName ?? 'Estudiante UA',
        'fecha_subida': FieldValue.serverTimestamp(),
      });

      // Se mantiene la estructura que permite abrir notificaciones
      await FirebaseFirestore.instance.collection('avisos').add({
        'titulo': 'Nuevo material de ${_materiaController.text.trim()}',
        'mensaje': 'Se ha publicado el archivo "${_nombreController.text.trim()}". ¡Échale un vistazo!',
        'fecha': FieldValue.serverTimestamp(), 
        'url': urlDescarga,
        'tipo': 'material'
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('¡Material publicado exitosamente!'), backgroundColor: Colors.green),
        );
        _nombreController.clear();
        _materiaController.clear();
        setState(() {
          _archivoFisico = null;
          _nombreArchivoOriginal = null;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al guardar: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _estaCargando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(30.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SizedBox(height: 20),
          const Icon(Icons.cloud_upload, size: 80, color: Colors.blue),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: _archivoFisico == null ? Colors.blue.shade50 : Colors.green.shade50,
              foregroundColor: _archivoFisico == null ? Colors.blue.shade700 : Colors.green.shade700,
              elevation: 0,
            ),
            onPressed: _seleccionarPDF,
            icon: Icon(_archivoFisico == null ? Icons.attach_file : Icons.check_circle),
            label: Text(_archivoFisico == null ? 'Seleccionar PDF' : 'PDF Seleccionado'),
          ),
          if (_nombreArchivoOriginal != null)
            Padding(
              padding: const EdgeInsets.only(top: 8.0),
              child: Text('Archivo: $_nombreArchivoOriginal', style: const TextStyle(fontSize: 12, color: Colors.grey)),
            ),
          const SizedBox(height: 30),
          TextField(
            controller: _nombreController,
            decoration: const InputDecoration(labelText: 'Nombre del Archivo (Ej: Guía de Área)', border: UnderlineInputBorder()),
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _materiaController,
            decoration: const InputDecoration(labelText: 'Materia (Ej: Cálculo II)', border: UnderlineInputBorder()),
          ),
          const SizedBox(height: 40),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, foregroundColor: Colors.white),
              onPressed: _estaCargando ? null : _guardarApunte,
              child: _estaCargando
                  ? const SizedBox(height: 25, width: 25, child: CircularProgressIndicator(color: Colors.white)) 
                  : const Text('Publicar Material', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }
}