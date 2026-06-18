import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class PantallaBiblioteca extends StatefulWidget {
  const PantallaBiblioteca({super.key});

  @override
  State<PantallaBiblioteca> createState() => _PantallaBibliotecaState();
}

class _PantallaBibliotecaState extends State<PantallaBiblioteca> {
  final TextEditingController _busquedaController = TextEditingController();
  List<dynamic> _libros = [];
  List<String> _favoritos = [];
  bool _cargando = false;
  String _mensajeError = '';

  @override
  void initState() {
    super.initState();
    _cargarFavoritos();
    // Búsqueda por defecto ideal para estudiantes de ingeniería
    _buscarLibros('Calculus Algebra');
  }

  // --- REQUISITO: Almacenamiento Local (SharedPreferences) ---
  Future<void> _cargarFavoritos() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _favoritos = prefs.getStringList('libros_favoritos') ?? [];
    });
  }

  Future<void> _toggleFavorito(String idLibro) async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      if (_favoritos.contains(idLibro)) {
        _favoritos.remove(idLibro);
      } else {
        _favoritos.add(idLibro);
      }
    });
    await prefs.setStringList('libros_favoritos', _favoritos);
  }

  // --- REQUISITO: Consumo API REST, JSON y Manejo de Errores ---
  Future<void> _buscarLibros(String query) async {
    if (query.trim().isEmpty) return;

    setState(() {
      _cargando = true;
      _mensajeError = '';
      _libros = [];
    });

    try {
      final url = Uri.parse('https://openlibrary.org/search.json?q=${Uri.encodeComponent(query)}&limit=15');
      final respuesta = await http.get(url).timeout(const Duration(seconds: 10));

      if (respuesta.statusCode == 200) {
        final datosDecodificados = json.decode(respuesta.body);
        setState(() {
          _libros = datosDecodificados['docs'] ?? [];
          if (_libros.isEmpty) {
            _mensajeError = 'No se encontraron libros para "$query".';
          }
        });
      } else {
        setState(() {
          _mensajeError = 'Error del servidor: ${respuesta.statusCode}. Intenta más tarde.';
        });
      }
    } catch (e) {
      setState(() {
        _mensajeError = 'Error de red. Verifica tu conexión a internet e intenta nuevamente.';
      });
    } finally {
      setState(() {
        _cargando = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Biblioteca Universitaria', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.blue.shade800,
        foregroundColor: Colors.white,
      ),
      backgroundColor: Colors.grey.shade100,
      body: Column(
        children: [
          // Barra de Búsqueda
          Container(
            color: Colors.blue.shade800,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: TextField(
              controller: _busquedaController,
              decoration: InputDecoration(
                hintText: 'Buscar libros (Ej: Thomas, Stewart, Grossman...)',
                fillColor: Colors.white,
                filled: true,
                suffixIcon: IconButton(
                  icon: const Icon(Icons.search, color: Colors.blue),
                  onPressed: () {
                    FocusScope.of(context).unfocus();
                    _buscarLibros(_busquedaController.text);
                  },
                ),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(30), borderSide: BorderSide.none),
                contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 0),
              ),
              onSubmitted: (valor) => _buscarLibros(valor),
            ),
          ),

          // Área de Resultados (Manejo de Estados)
          Expanded(
            child: _cargando
                ? const Center(child: CircularProgressIndicator())
                : _mensajeError.isNotEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(20.0),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.error_outline, size: 60, color: Colors.red),
                              const SizedBox(height: 16),
                              Text(_mensajeError, textAlign: TextAlign.center, style: const TextStyle(color: Colors.grey, fontSize: 16)),
                            ],
                          ),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(12),
                        itemCount: _libros.length,
                        itemBuilder: (context, index) {
                          final libro = _libros[index];
                          
                          // Extracción segura de datos JSON
                          final String idLibro = libro['key'] ?? index.toString();
                          final String titulo = libro['title'] ?? 'Sin título';
                          final String autor = (libro['author_name'] != null && (libro['author_name'] as List).isNotEmpty)
                              ? libro['author_name'][0]
                              : 'Autor desconocido';
                          final int? coverId = libro['cover_i'];
                          final String coverUrl = coverId != null
                              ? 'https://covers.openlibrary.org/b/id/$coverId-M.jpg'
                              : 'https://via.placeholder.com/150x200.png?text=Sin+Portada';
                          
                          final bool esFavorito = _favoritos.contains(idLibro);

                          return Card(
                            elevation: 2,
                            margin: const EdgeInsets.only(bottom: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            child: Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: Row(
                                children: [
                                  // Portada del libro
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: Image.network(
                                      coverUrl,
                                      width: 70,
                                      height: 100,
                                      fit: BoxFit.cover,
                                      errorBuilder: (context, error, stackTrace) => Container(
                                        width: 70, height: 100, color: Colors.grey.shade300,
                                        child: const Icon(Icons.book, color: Colors.grey),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 15),
                                  // Detalles
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(titulo, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16), maxLines: 2, overflow: TextOverflow.ellipsis),
                                        const SizedBox(height: 5),
                                        Text(autor, style: TextStyle(color: Colors.grey.shade700, fontSize: 14)),
                                      ],
                                    ),
                                  ),
                                  // Botón de Favorito Local
                                  IconButton(
                                    icon: Icon(esFavorito ? Icons.bookmark : Icons.bookmark_border),
                                    color: esFavorito ? Colors.orange : Colors.grey,
                                    onPressed: () => _toggleFavorito(idLibro),
                                    tooltip: esFavorito ? 'Quitar de favoritos' : 'Guardar en favoritos',
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}