import 'package:flutter/material.dart';
import '../main.dart'; 
import 'pantalla_cursos.dart';
import 'pantalla_perfil.dart';
import 'vistas_secundarias.dart';
import 'pantalla_avisos.dart';
import 'pantalla_biblioteca.dart';
class PantallaInicio extends StatefulWidget {
  const PantallaInicio({super.key});

  @override
  State<PantallaInicio> createState() => _PantallaInicioState();
}

class _PantallaInicioState extends State<PantallaInicio> {
  int _indiceActual = 0;

  final List<Widget> _paginas = [
    const VistaApuntes(),
    const VistaTutores(),
    const VistaSubir(),
    const PantallaPerfil(), 
    const PantallaCursos(),
  ];

  @override
  void initState() {
    super.initState();
    // Espera a que termine el renderizado del primer frame de la PantallaInicio
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (abrirAvisosAlInicio) {
        abrirAvisosAlInicio = false; // Bajamos la bandera inmediatamente
        if (mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const PantallaAvisos()),
          );
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('CampusSync', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        automaticallyImplyLeading: false, 
        actions: [
          // NUEVO: Acceso a la Biblioteca Virtual (API Externa)
          IconButton(
            icon: const Icon(Icons.local_library, color: Colors.blue),
            tooltip: 'Biblioteca Virtual',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const PantallaBiblioteca()),
              );
            },
          ),
          // Botón de notificaciones que ya tenías
          IconButton(
            icon: const Icon(Icons.notifications_active, color: Colors.blue),
            tooltip: 'Ver Avisos',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const PantallaAvisos()),
              );
            },
          ),
          const SizedBox(width: 10),
        ],
      ),
      body: _paginas[_indiceActual], 
      bottomNavigationBar: NavigationBar(
        selectedIndex: _indiceActual,
        onDestinationSelected: (int index) {
          setState(() {
            _indiceActual = index;
          });
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.library_books_outlined),
            selectedIcon: Icon(Icons.library_books, color: Colors.blue),
            label: 'Apuntes',
          ),
          NavigationDestination(
            icon: Icon(Icons.people_outline),
            selectedIcon: Icon(Icons.people, color: Colors.blue),
            label: 'Tutores',
          ),
          NavigationDestination(
            icon: Icon(Icons.upload_file_outlined),
            selectedIcon: Icon(Icons.upload_file, color: Colors.blue),
            label: 'Subir',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person, color: Colors.blue),
            label: 'Perfil',
          ),
          NavigationDestination(
            icon: Icon(Icons.school_outlined),
            selectedIcon: Icon(Icons.school, color: Colors.blue),
            label: 'Cursos',
          ),
        ],
      ),
    );
  }
}