import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart' as google_auth;
import 'package:cloud_firestore/cloud_firestore.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(const CampusSyncApp());
}

class CampusSyncApp extends StatelessWidget {
  const CampusSyncApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'CampusSync',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(body: Center(child: CircularProgressIndicator()));
          }
          
          if (snapshot.hasData) {
            // SOLO si el correo está verificado o si entró por Google (Google ya viene verificado)
            if (snapshot.data!.emailVerified) {
              return const PantallaInicio();
            }
          }
          
          return const PantallaLogin();
        },
      ),
    );
  }
}


// 1. PANTALLA LOGIN

class PantallaLogin extends StatefulWidget {
  const PantallaLogin({super.key});

  @override
  State<PantallaLogin> createState() => _PantallaLoginState();
}

class _PantallaLoginState extends State<PantallaLogin> {
  final TextEditingController _userController = TextEditingController();
  final TextEditingController _passController = TextEditingController();
  String _mensajeError = '';

  bool _esCorreoValido(String email) {
    final RegExp regex = RegExp(r'^[^@]+@[^@]+\.[^@]+');
    return regex.hasMatch(email);
  }

  void _validarIngreso() async {
    // 1. Validar campos vacíos
    if (_userController.text.trim().isEmpty || _passController.text.trim().isEmpty) {
      setState(() => _mensajeError = 'Debes ingresar tu correo y contraseña.');
      return;
    }
    
    // 2. Validar formato de correo
    if (!_esCorreoValido(_userController.text.trim())) {
      setState(() => _mensajeError = 'El formato del correo no es válido.');
      return;
    }
    
    setState(() => _mensajeError = 'Iniciando sesión...');

    try {
      UserCredential userCredential = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _userController.text.trim(),
        password: _passController.text,
      );

      // 3. REVISAR SI EL CORREO ESTÁ VALIDADO (Punto 7 y 14)
      if (userCredential.user != null && !userCredential.user!.emailVerified) {
        // Si no está validado, se cuerra la sesión para que no quede "atrapado" logueado a medias
        await FirebaseAuth.instance.signOut();
        setState(() => _mensajeError = 'Debes verificar tu correo antes de entrar. Revisa tu bandeja de entrada.');
        return;
      }

    } on FirebaseAuthException catch (e) {
      String mensaje = '';
      if (e.code == 'user-not-found' || e.code == 'invalid-credential') {
        mensaje = 'Correo no registrado o contraseña incorrecta.';
      } else if (e.code == 'wrong-password') {
        mensaje = 'Contraseña incorrecta.';
      } else {
        mensaje = 'Error de conexión: ${e.message}';
      }
      setState(() => _mensajeError = mensaje);
    }
  }

  void _ingresarConGoogle() async {
    try {
      final google_auth.GoogleSignIn googleSignIn = google_auth.GoogleSignIn();
      final google_auth.GoogleSignInAccount? googleUser = await googleSignIn.signIn();
      if (googleUser == null) return; 
      final google_auth.GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );
      await FirebaseAuth.instance.signInWithCredential(credential);
      // Fuerza la purga de cualquier ruta apilada para exponer el redibujado del StreamBuilder raíz
      if (mounted) Navigator.of(context).popUntil((route) => route.isFirst);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error con Google: ${e.toString()}')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('CampusSync - Ingreso'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(30.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.school, size: 100, color: Colors.blue),
                const SizedBox(height: 20),
                TextField(
                  controller: _userController,
                  decoration: const InputDecoration(labelText: 'Correo Institucional', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 15),
                TextField(
                  controller: _passController,
                  obscureText: true,
                  decoration: const InputDecoration(labelText: 'Contraseña', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 10),
                Text(_mensajeError, style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
                const SizedBox(height: 20),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 50)),
                  onPressed: _validarIngreso,
                  child: const Text('Entrar a la Universidad'),
                ),
                const SizedBox(height: 15),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.black,
                    minimumSize: const Size(double.infinity, 50),
                  ),
                  icon: const Icon(Icons.g_mobiledata, size: 30, color: Colors.blue),
                  label: const Text('Ingresar con Google'),
                  onPressed: _ingresarConGoogle,
                ),
                const SizedBox(height: 20),
                TextButton(
                  onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const PantallaRegistro())),
                  child: const Text('¿No tienes cuenta? Regístrate'),
                ),
                TextButton(
                  onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const PantallaRecuperar())),
                  child: const Text('¿Olvidaste tu contraseña?'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}


// 2. PANTALLA INICIO

class PantallaInicio extends StatefulWidget {
  const PantallaInicio({super.key});

  @override
  State<PantallaInicio> createState() => _PantallaInicioState();
}

class _PantallaInicioState extends State<PantallaInicio> {
  int _indiceActual = 0;

  // Lista de las 4 pantallas principales de la aplicación
  final List<Widget> _paginas = [
    const VistaApuntes(),
    const VistaTutores(),
    const VistaSubir(),
    const PantallaPerfil(), 
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('CampusSync', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        automaticallyImplyLeading: false, 
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
        ],
      ),
    );
  }
}


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
    // 1. Obtenemos el ID del usuario que está usando la app AHORA
    final String uidActual = FirebaseAuth.instance.currentUser?.uid ?? '';

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('apuntes')
          .orderBy('fecha_subida', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        // Manejo de carga
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        // Manejo de errores
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        // Si está vacío
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
                // Crear publicación en la colección 'tutores'
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
              // Borramos el documento de la colección 'tutores'
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
            return const Center(child: CircularProgressIndicator()); // Punto 10: Estado de carga
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
                  // Solo el dueño puede ver el botón para eliminar su anuncio
                  // Busca esta parte dentro de tu ListView.builder:
                  trailing: uidActual == tutor['uid']
                      ? IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          onPressed: () => _confirmarEliminacionTutor(context, docId), // Llamada a la confirmación
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
  // Controladores para atrapar lo que el usuario escribe
  final TextEditingController _nombreController = TextEditingController();
  final TextEditingController _materiaController = TextEditingController();
  
  // Estado de carga 
  bool _estaCargando = false;

  void _guardarApunte() async {
    // Validaciones antes de guardar 
    if (_nombreController.text.trim().isEmpty || _materiaController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor, completa todos los campos.'), backgroundColor: Colors.red),
      );
      return;
    }

    setState(() => _estaCargando = true);

    try {
      // Asociar datos al usuario autenticado
      final User? usuario = FirebaseAuth.instance.currentUser;
      if (usuario == null) throw Exception('Debes iniciar sesión para subir material');

      // Crear registro en Firestore 
      await FirebaseFirestore.instance.collection('apuntes').add({
        'nombre_archivo': _nombreController.text.trim(),
        'materia': _materiaController.text.trim(),
        'autor_id': usuario.uid, // Guardamos el ID único del alumno
        'autor_nombre': usuario.displayName ?? 'Estudiante',
        'fecha_subida': FieldValue.serverTimestamp(), // Hora exacta del servidor
      });

      // Mensaje de éxito y limpieza de formulario 
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
                  ? const SizedBox(height: 25, width: 25, child: CircularProgressIndicator()) // Punto 10
                  : const Text('Guardar Material', style: TextStyle(fontSize: 16)),
            ),
          ),
        ],
      ),
    );
  }
}


// 3. PANTALLA APUNTES

class PantallaApuntes extends StatefulWidget {
  const PantallaApuntes({super.key});

  @override
  State<PantallaApuntes> createState() => _PantallaApuntesState();
}

class _PantallaApuntesState extends State<PantallaApuntes> {
  // Lista de datos simulando nuestra base de materias
  final List<Map<String, dynamic>> _todasLasMaterias = [
    {'nombre': 'Base de Datos 2', 'icono': Icons.storage, 'color': Colors.blue, 'facultad': 'Ingeniería'},
    {'nombre': 'Programación en Python', 'icono': Icons.code, 'color': Colors.green, 'facultad': 'Ingeniería'},
    {'nombre': 'Termodinámica', 'icono': Icons.local_fire_department, 'color': Colors.orange, 'facultad': 'Ciencias'},
    {'nombre': 'Cálculo Avanzado', 'icono': Icons.functions, 'color': Colors.red, 'facultad': 'matemáticas'},
    {'nombre': 'Anatomía Básica', 'icono': Icons.favorite, 'color': Colors.pink, 'facultad': 'Ciencias de la salud'},
  ];

  List<Map<String, dynamic>> _materiasMostradas = [];
  String _facultadSeleccionada = 'Todas';
  String _textoBusqueda = '';

  @override
  void initState() {
    super.initState();
    _materiasMostradas = List.from(_todasLasMaterias);
  }

  // Lógica de filtrado
  void _aplicarFiltros() {
    setState(() {
      _materiasMostradas = _todasLasMaterias.where((materia) {
        final coincideTexto = materia['nombre'].toLowerCase().contains(_textoBusqueda.toLowerCase());
        final coincideFacultad = _facultadSeleccionada == 'Todas' || materia['facultad'] == _facultadSeleccionada;
        return coincideTexto && coincideFacultad;
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Asignaturas')),
      body: Column(
        children: [
          // Barra de Búsqueda simple
          Padding(
            padding: const EdgeInsets.all(10.0),
            child: TextField(
              onChanged: (valor) {
                _textoBusqueda = valor;
                _aplicarFiltros();
              },
              decoration: const InputDecoration(
                hintText: 'Buscar asignatura...',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
            ),
          ),

          // Botones de filtro de facultad
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Row(
              children: [
                _crearFiltroChip('Todas'),
                const SizedBox(width: 8),
                _crearFiltroChip('Ingeniería'),
                const SizedBox(width: 8),
                _crearFiltroChip('Ciencias'),
                const SizedBox(width: 8),
                _crearFiltroChip('Salud'),
              ],
            ),
          ),
          const SizedBox(height: 10),

          // Lista de resultados mostrados con un ListView normal
          Expanded(
            child: _materiasMostradas.isEmpty
                ? const Center(child: Text('No se encontraron asignaturas.'))
                : ListView(
                    padding: const EdgeInsets.all(10),
                    children: _materiasMostradas.map((materia) {
                      return _filaMateria(context, materia['nombre'], materia['icono'], materia['color'], materia['facultad']);
                    }).toList(),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _crearFiltroChip(String nombreFacultad) {
    final bool seleccionado = _facultadSeleccionada == nombreFacultad;
    return FilterChip(
      label: Text(nombreFacultad, style: TextStyle(color: seleccionado ? Colors.white : Colors.black87)),
      backgroundColor: Colors.grey.shade200,
      selectedColor: Colors.blue,
      selected: seleccionado,
      onSelected: (bool valor) {
        _facultadSeleccionada = nombreFacultad;
        _aplicarFiltros();
      },
    );
  }

  Widget _filaMateria(BuildContext contexto, String nombre, IconData icono, Color color, String facultad) {
    return Card(
      child: ListTile(
        leading: Icon(icono, color: color),
        title: Text(nombre),
        subtitle: Text(facultad),
        trailing: const Icon(Icons.arrow_forward_ios, size: 14),
        onTap: () {
          Navigator.push(contexto, MaterialPageRoute(builder: (context) => PantallaRepositorioReal(nombreMateria: nombre)));
        },
      ),
    );
  }
}


// 4. PANTALLA REPOSITORIO

class PantallaRepositorioReal extends StatelessWidget {
  final String nombreMateria;
  const PantallaRepositorioReal({super.key, required this.nombreMateria});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Apuntes de $nombreMateria'), backgroundColor: Colors.blue, foregroundColor: Colors.white),
      body: ListView(
        padding: const EdgeInsets.all(10),
        children: [
          _elementoArchivo('Resumen y Esquemas', 'Estudiante 01', '4.8'),
          _elementoArchivo('Proyectos Resueltos', 'Juan Desarrollador', '4.5'),
          _elementoArchivo('Guía de Preparación Final', 'Maria Ingeniera', '5.0'),
        ],
      ),
    );
  }

  Widget _elementoArchivo(String titulo, String autor, String estrellas) {
    return Card(
      child: ListTile(
        leading: const Icon(Icons.picture_as_pdf, color: Colors.red),
        title: Text(titulo),
        subtitle: Text('Por: $autor • ⭐ $estrellas'),
        trailing: const Icon(Icons.download, color: Colors.blue),
      ),
    );
  }
}


// 5. PANTALLA TUTORES

class PantallaTutores extends StatelessWidget {
  const PantallaTutores({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Tutores Disponibles')),
      body: ListView(
        padding: const EdgeInsets.all(10),
        children: [
          _tarjetaTutor(context, 'Prof. Cristofher Rojas', 'Desarrollo de Apps', Colors.blue, '\$10.000'),
          _tarjetaTutor(context, 'Ayudante Hernán Escobar', 'Cálculo y Álgebra', Colors.red, '\$5.000'),
          _tarjetaTutor(context, 'Ing. Rodolfo Durán', 'Base de Datos', Colors.green, '\$8.000'),
        ],
      ),
    );
  }

  Widget _tarjetaTutor(BuildContext context, String nombre, String especialidad, Color color, String precio) {
    return Card(
      child: ListTile(
        leading: CircleAvatar(backgroundColor: color, child: const Icon(Icons.person, color: Colors.white)),
        title: Text(nombre, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text('$especialidad \nTarifa: $precio/hr'),
        isThreeLine: true,
        trailing: ElevatedButton(
          onPressed: () {

            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Abriendo chat con $nombre...')),
            );
          },
          child: const Text('Contactar'),
        ),
      ),
    );
  }
}


// 6. PANTALLA SUBIR APUNTES

class PantallaSubirApuntes extends StatelessWidget {
  const PantallaSubirApuntes({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Compartir Material')),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            const Icon(Icons.cloud_upload, size: 80, color: Colors.blue),
            const TextField(decoration: InputDecoration(labelText: 'Nombre del Archivo')),
            const TextField(decoration: InputDecoration(labelText: 'Materia')),
            const SizedBox(height: 30),
            ElevatedButton(onPressed: () {}, child: const Text('Seleccionar PDF')),
          ],
        ),
      ),
    );
  }
}


// 7. PANTALLA PERFIL

class PantallaPerfil extends StatefulWidget {
  const PantallaPerfil({super.key});

  @override
  State<PantallaPerfil> createState() => _PantallaPerfilState();
}

class _PantallaPerfilState extends State<PantallaPerfil> {
  final User? user = FirebaseAuth.instance.currentUser;

  void _editarNombre() {
    TextEditingController nombreController = TextEditingController(text: user?.displayName ?? '');

    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Editar Nombre'),
          content: TextField(
            controller: nombreController,
            decoration: const InputDecoration(hintText: "Ingresa tu nuevo nombre"),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (nombreController.text.trim().isNotEmpty) {
                  await user?.updateDisplayName(nombreController.text.trim());
                  await user?.reload();
                  
                  if (!dialogContext.mounted) return;
                  Navigator.pop(dialogContext);
                  
                  if (!mounted) return;
                  setState(() {});
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Nombre actualizado en Firebase')),
                  );
                }
              },
              child: const Text('Guardar'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Mi Perfil')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Center(
            child: CircleAvatar(
              radius: 60,
              backgroundImage: user?.photoURL != null ? NetworkImage(user!.photoURL!) : null,
              child: user?.photoURL == null ? const Icon(Icons.person, size: 80) : null,
            ),
          ),
          const SizedBox(height: 20),
          Center(child: Text(user?.displayName ?? 'Estudiante UA', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold))),
          Center(child: Text(user?.email ?? '', style: const TextStyle(fontSize: 16, color: Colors.grey))),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: _editarNombre,
            icon: const Icon(Icons.edit),
            label: const Text('Editar Nombre'),
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade50, foregroundColor: Colors.red),
            onPressed: () async {
              // Revoca la autorización local de la cuenta de Google para forzar el selector en el próximo login
              await google_auth.GoogleSignIn().signOut();
              await FirebaseAuth.instance.signOut();
            },
            icon: const Icon(Icons.logout),
            label: const Text('Cerrar Sesión'),
          ),
        ],
      ),
    );
  }
}


// NUEVA PANTALLA REGISTRO

class PantallaRegistro extends StatefulWidget {
  const PantallaRegistro({super.key});

  @override
  State<PantallaRegistro> createState() => _PantallaRegistroState();
}

class _PantallaRegistroState extends State<PantallaRegistro> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passController = TextEditingController();
  final TextEditingController _confirmPassController = TextEditingController();
  String _mensajeError = '';

  // 1. Validar formato de correo con RegExp
  bool _esCorreoValido(String email) {
    final RegExp regex = RegExp(r'^[^@]+@[^@]+\.[^@]+');
    return regex.hasMatch(email);
  }

  // 2. Validar contraseña estricta con RegExp
  bool _esContrasenaSegura(String password) {
    if (password.length < 8) return false; // Mínimo 8 caracteres
    if (!password.contains(RegExp(r'[A-Z]'))) return false; // Al menos una mayúscula
    if (!password.contains(RegExp(r'[a-z]'))) return false; // Al menos una minúscula
    if (!password.contains(RegExp(r'[0-9]'))) return false; // Al menos un número
    
    // NUEVA REGLA: Al menos un carácter que NO sea letra (a-z, A-Z) ni número (0-9)
    if (!password.contains(RegExp(r'[^a-zA-Z0-9]'))) return false; 
    
    return true;
  }

  void _registrar() async {
    if (_emailController.text.trim().isEmpty || _passController.text.trim().isEmpty || _confirmPassController.text.trim().isEmpty) {
      setState(() => _mensajeError = 'Todos los campos son obligatorios.');
      return;
    }
    if (!_esCorreoValido(_emailController.text.trim())) {
      setState(() => _mensajeError = 'Formato de correo inválido.');
      return;
    }
    if (!_esContrasenaSegura(_passController.text)) {
      setState(() => _mensajeError = 'La contraseña debe ser más segura (8+ caracteres, Mayús, Núm, Símbolo).');
      return;
    }
    if (_passController.text != _confirmPassController.text) {
      setState(() => _mensajeError = 'Las contraseñas no coinciden.');
      return;
    }
    try {
      UserCredential userCredential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passController.text,
      );
      await userCredential.user?.sendEmailVerification();
      // Destruye la sesión automática de Firebase tras registro para evitar bloqueos del StreamBuilder por falta de verificación
      await FirebaseAuth.instance.signOut();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Registro exitoso. Revisa tu correo para verificar y luego inicia sesión.')),
        );
        if (Navigator.canPop(context)) Navigator.pop(context);
      }
    } on FirebaseAuthException catch (e) {
      setState(() => _mensajeError = 'Error: ${e.message}');
    }
  }
  void _ingresarConGoogle() async {
    try {
      final google_auth.GoogleSignIn googleSignIn = google_auth.GoogleSignIn();
      final google_auth.GoogleSignInAccount? googleUser = await googleSignIn.signIn();
      if (googleUser == null) return;
      final google_auth.GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );
      await FirebaseAuth.instance.signInWithCredential(credential);
      // Asegura la destrucción de la capa de registro actual permitiendo que el StreamBuilder muestre PantallaInicio
      if (mounted && Navigator.canPop(context)) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al registrar con Google: $e'))
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Registro'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(30.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.school, size: 100, color: Colors.blue),
                const SizedBox(height: 20),
                TextField(
                  controller: _emailController,
                  decoration: const InputDecoration(labelText: 'Correo Institucional', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 15),
                TextField(
                  controller: _passController,
                  obscureText: true,
                  decoration: const InputDecoration(labelText: 'Contraseña', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 15),
                TextField(
                  controller: _confirmPassController,
                  obscureText: true,
                  decoration: const InputDecoration(labelText: 'Confirmar Contraseña', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 10),
                Text(_mensajeError, style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
                const SizedBox(height: 20),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 50)),
                  onPressed: _registrar,
                  child: const Text('Registrarse'),
                ),
                const SizedBox(height: 15),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white, 
                    foregroundColor: Colors.black, 
                    minimumSize: const Size(double.infinity, 50)
                  ),
                  icon: const Icon(Icons.g_mobiledata, size: 30, color: Colors.blue),
                  label: const Text('Registrarse con Google'),
                  onPressed: _ingresarConGoogle,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}


// NUEVA PANTALLA RECUPERAR

class PantallaRecuperar extends StatefulWidget {
  const PantallaRecuperar({super.key});

  @override
  State<PantallaRecuperar> createState() => _PantallaRecuperarState();
}

class _PantallaRecuperarState extends State<PantallaRecuperar> {
  final TextEditingController _emailController = TextEditingController();
  String _mensaje = '';

  void _recuperar() async {
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: _emailController.text);
      setState(() => _mensaje = 'Correo de recuperación enviado.');
    } catch (e) {
      setState(() => _mensaje = 'Error: ${e.toString()}');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Recuperar Contraseña'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(30.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.email, size: 100, color: Colors.blue),
            const SizedBox(height: 20),
            TextField(
              controller: _emailController,
              decoration: const InputDecoration(labelText: 'Correo Institucional', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 10),
            Text(_mensaje, style: const TextStyle(color: Colors.blue)),
            const SizedBox(height: 20),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue, // Fondo azul
                foregroundColor: Colors.white, // Letra blanca
                minimumSize: const Size(double.infinity, 50)
              ),
              onPressed: _recuperar, 
              child: const Text('Enviar Correo de Recuperación'),
            ),
          ],
        ),
      ),
    );
  }
}
