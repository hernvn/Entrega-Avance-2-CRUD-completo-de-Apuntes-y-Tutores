import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'pantalla_detalle_curso.dart';

class PantallaCursos extends StatefulWidget {
  const PantallaCursos({super.key});

  @override
  State<PantallaCursos> createState() => _PantallaCursosState();
}

class _PantallaCursosState extends State<PantallaCursos> {
  late Stream<QuerySnapshot> _cursosStream;
  String _textoBusqueda = "";

  @override
  void initState() {
    super.initState();
    _cursosStream = FirebaseFirestore.instance
        .collection('cursos')
        .orderBy('fechaCreacion', descending: true)
        .snapshots();
  }

  Future<void> _mostrarDialogoNuevoCurso(BuildContext context) async {
    final TextEditingController tituloController = TextEditingController();
    final TextEditingController descripcionController = TextEditingController(); 
    String visibilidadSeleccionada = 'publico';
    bool guardando = false;

    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: const Text('Crear Nuevo Curso'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: tituloController,
                      decoration: const InputDecoration(
                        labelText: 'Título (ej. Cálculo II, Álgebra)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 15),
                    TextField(
                      controller: descripcionController,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: 'Descripción (¿Qué ofrece el curso?)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 15),
                    DropdownButtonFormField<String>(
                      initialValue: visibilidadSeleccionada,
                      decoration: const InputDecoration(
                        labelText: 'Visibilidad',
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'publico', child: Text('Público')),
                        DropdownMenuItem(value: 'privado', child: Text('Privado')),
                      ],
                      onChanged: (String? nuevoValor) {
                        if (nuevoValor != null) {
                          setStateDialog(() {
                            visibilidadSeleccionada = nuevoValor;
                          });
                        }
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: guardando ? null : () => Navigator.pop(context),
                  child: const Text('Cancelar'),
                ),
                ElevatedButton(
                  onPressed: guardando
                      ? null
                      : () async {
                          if (tituloController.text.trim().isEmpty) return;

                          setStateDialog(() {
                            guardando = true;
                          });

                          try {
                            final String? uid = FirebaseAuth.instance.currentUser?.uid;
                            
                            if (uid != null) {
                              final docRef = FirebaseFirestore.instance.collection('cursos').doc();

                              await docRef.set({
                                'id': docRef.id,
                                'titulo': tituloController.text.trim(),
                                'descripcion': descripcionController.text.trim(),
                                'visibilidad': visibilidadSeleccionada,
                                'creadorId': uid,
                                'fechaCreacion': FieldValue.serverTimestamp(),
                              });
                            }

                            if (!context.mounted) return;
                            Navigator.pop(context);
                            
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Curso creado con éxito'),
                                backgroundColor: Colors.green,
                              ),
                            );
                          } catch (e) {
                            setStateDialog(() {
                              guardando = false;
                            });
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
                            );
                          }
                        },
                  child: guardando
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Text('Crear Curso'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _eliminarCursoCompleto(String cursoId) async {
    bool confirmar = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar Ayudantía'),
        content: const Text('¿Estás seguro? Se borrarán todos los materiales en PDF y se eliminará a los alumnos matriculados. Esta acción no se puede deshacer.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Eliminar', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    ) ?? false;

    if (!confirmar) return;
    if (!mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      var materiales = await FirebaseFirestore.instance
          .collection('cursos')
          .doc(cursoId)
          .collection('materiales')
          .get();

      for (var doc in materiales.docs) {
        String urlArchivo = doc.data()['url'] ?? '';
        if (urlArchivo.isNotEmpty) {
          try {
            await FirebaseStorage.instance.refFromURL(urlArchivo).delete();
          } catch (e) {
            debugPrint('Error al borrar PDF físico: $e');
          }
        }
        await doc.reference.delete();
      }

      var matriculados = await FirebaseFirestore.instance
          .collection('cursos')
          .doc(cursoId)
          .collection('matriculados')
          .get();
          
      for (var doc in matriculados.docs) {
        await doc.reference.delete();
      }

      await FirebaseFirestore.instance.collection('cursos').doc(cursoId).delete();

      if (!mounted) return;
      Navigator.pop(context);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Curso y materiales eliminados por completo.'),
          backgroundColor: Colors.orange,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al eliminar el curso: $e'), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mis Ayudantías'),
      ),
      body: Column(
        children: [
          // BARRA DE BÚSQUEDA
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              onChanged: (valor) {
                setState(() {
                  _textoBusqueda = valor.toLowerCase();
                });
              },
              decoration: InputDecoration(
                hintText: 'Buscar curso por título o descripción...',
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
          
          // LISTA DE CURSOS
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _cursosStream,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(child: Text('Error al cargar los cursos: ${snapshot.error}'));
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(child: Text('Aún no hay cursos disponibles. Crea el primero.'));
                }

                // LÓGICA DE FILTRADO LOCAL
                final cursosFiltrados = snapshot.data!.docs.where((doc) {
                  var data = doc.data() as Map<String, dynamic>;
                  String titulo = (data['titulo'] ?? '').toString().toLowerCase();
                  String descripcion = (data['descripcion'] ?? '').toString().toLowerCase();
                  
                  if (_textoBusqueda.isEmpty) return true;
                  return titulo.contains(_textoBusqueda) || descripcion.contains(_textoBusqueda);
                }).toList();

                if (cursosFiltrados.isEmpty) {
                  return const Center(
                    child: Text('No se encontraron cursos.', style: TextStyle(color: Colors.grey)),
                  );
                }

                return ListView.builder(
                  itemCount: cursosFiltrados.length,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemBuilder: (context, index) {
                    var doc = cursosFiltrados[index];
                    var cursoData = doc.data() as Map<String, dynamic>;
                    
                    cursoData['id'] = doc.id; 

                    final String? usuarioActualId = FirebaseAuth.instance.currentUser?.uid;
                    String titulo = cursoData['titulo'] ?? 'Curso sin título';
                    String descripcion = cursoData['descripcion'] ?? 'Sin descripción disponible.';
                    String visibilidad = cursoData['visibilidad'] ?? 'publico';

                    final bool esPrivado = visibilidad == 'privado';

                    return Card(
                      elevation: 2,
                      margin: const EdgeInsets.only(bottom: 12),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        leading: CircleAvatar(
                          backgroundColor: esPrivado ? Colors.orange.shade100 : Colors.blue.shade100,
                          child: Icon(
                            esPrivado ? Icons.lock : Icons.book, 
                            color: esPrivado ? Colors.orange.shade800 : Colors.blue.shade800
                          ),
                        ),
                        title: Text(
                          titulo,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 4),
                            Text(
                              descripcion,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
                            ),
                            const SizedBox(height: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: esPrivado ? Colors.orange.shade50 : Colors.green.shade50,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                visibilidad.toUpperCase(),
                                style: TextStyle(
                                  color: esPrivado ? Colors.orange.shade800 : Colors.green.shade800,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (cursoData['creadorId'] == usuarioActualId)
                              IconButton(
                                icon: const Icon(Icons.delete_outline, color: Colors.red),
                                onPressed: () => _eliminarCursoCompleto(doc.id),
                              ),
                            const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
                          ],
                        ),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => PantallaDetalleCurso(curso: cursoData),
                            ),
                          );
                        },
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _mostrarDialogoNuevoCurso(context),
        child: const Icon(Icons.add),
      ),
    );
  }
}