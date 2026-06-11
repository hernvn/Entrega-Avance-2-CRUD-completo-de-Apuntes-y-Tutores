import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart'; // <-- Agregamos autenticación directa
import 'package:pie_chart/pie_chart.dart';
import 'pantalla_reportes.dart';
import 'pantalla_gestion_usuarios.dart';

class PantallaDashboard extends StatefulWidget {
  final String? rolUsuario;

  const PantallaDashboard({super.key, this.rolUsuario = 'estudiante'});

  @override
  State<PantallaDashboard> createState() => _PantallaDashboardState();
}

class _PantallaDashboardState extends State<PantallaDashboard> {
  int totalUsuarios = 0;
  int totalApuntes = 0;
  int totalCursos = 0;
  bool cargandoMetricas = true;
  String rolActual = 'estudiante'; // <-- Esta variable manejará el estado real

  @override
  void initState() {
    super.initState();
    rolActual = widget.rolUsuario ?? 'estudiante'; // Inicializa con el valor recibido
    _cargarMetricas();
  }

  Future<void> _cargarMetricas() async {
    try {
      // VALIDACIÓN EN TIEMPO REAL: Consultamos a Firebase el rol exacto del usuario actual
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid != null) {
        final userDoc = await FirebaseFirestore.instance.collection('usuarios').doc(uid).get();
        if (userDoc.exists && mounted) {
          setState(() {
            rolActual = (userDoc.data() as Map<String, dynamic>)['rol'] ?? 'estudiante';
          });
        }
      }

      // Carga de KPIs normales
      final usuariosSnap = await FirebaseFirestore.instance.collection('usuarios').count().get();
      final apuntesSnap = await FirebaseFirestore.instance.collection('apuntes').count().get();
      final cursosSnap = await FirebaseFirestore.instance.collection('cursos').count().get();

      if (mounted) {
        setState(() {
          totalUsuarios = usuariosSnap.count ?? 0;
          totalApuntes = apuntesSnap.count ?? 0;
          totalCursos = cursosSnap.count ?? 0;
          cargandoMetricas = false;
        });
      }
    } catch (e) {
      debugPrint("Error al cargar métricas: $e");
      if (mounted) setState(() => cargandoMetricas = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    Map<String, double> datosGrafico = {
      "Usuarios": totalUsuarios.toDouble(),
      "Apuntes": totalApuntes.toDouble(),
      "Cursos": totalCursos.toDouble(),
    };

    return Scaffold(
      appBar: AppBar(
        title: Text('Panel - Rol detectado: $rolActual', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        backgroundColor: Colors.blueGrey.shade900,
        foregroundColor: Colors.white,
      ),
      backgroundColor: Colors.grey.shade100,
      body: cargandoMetricas
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Métricas Generales', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 15),
                  
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _crearTarjetaKPI('Usuarios', totalUsuarios.toString(), Icons.people, Colors.blue),
                      _crearTarjetaKPI('Materiales', totalApuntes.toString(), Icons.picture_as_pdf, Colors.red),
                      _crearTarjetaKPI('Cursos', totalCursos.toString(), Icons.school, Colors.green),
                    ],
                  ),
                  
                  const SizedBox(height: 30),
                  const Text('Distribución del Sistema', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 20),

                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(15), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10)]),
                    child: PieChart(
                      dataMap: datosGrafico,
                      animationDuration: const Duration(milliseconds: 800),
                      chartLegendSpacing: 32,
                      chartRadius: MediaQuery.of(context).size.width / 2.5,
                      colorList: const [Colors.blue, Colors.red, Colors.green],
                      initialAngleInDegree: 0,
                      chartType: ChartType.ring,
                      ringStrokeWidth: 32,
                      legendOptions: const LegendOptions(showLegendsInRow: false, legendPosition: LegendPosition.right, showLegends: true, legendTextStyle: TextStyle(fontWeight: FontWeight.bold)),
                      chartValuesOptions: const ChartValuesOptions(showChartValueBackground: true, showChartValues: true, showChartValuesInPercentage: false, showChartValuesOutside: false, decimalPlaces: 0),
                    ),
                  ),

                  const SizedBox(height: 25),
                  
                  SizedBox(
                    width: double.infinity,
                    height: 55,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red.shade50,
                        foregroundColor: Colors.red.shade800,
                        elevation: 0,
                        side: BorderSide(color: Colors.red.shade200, width: 1),
                      ),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const PantallaReportes()),
                        ).then((_) => _cargarMetricas()); // Al volver de reportes, recarga
                      },
                      icon: const Icon(Icons.admin_panel_settings),
                      label: const Text('Revisar Bandeja de Reportes', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    ),
                  ),

                  const SizedBox(height: 15),

                  // EL CANDADO AHORA DEPENDE DEL ROL REAL DE FIREBASE
                  if (rolActual == 'admin')
                    SizedBox(
                      width: double.infinity,
                      height: 55,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue.shade50,
                          foregroundColor: Colors.blue.shade800,
                          elevation: 0,
                          side: BorderSide(color: Colors.blue.shade200, width: 1),
                        ),
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => const PantallaGestionUsuarios()),
                          ).then((_) => _cargarMetricas()); // AL VOLVER, REFRESCARÁ TU ROL AL INSTANTE
                        },
                        icon: const Icon(Icons.people_alt),
                        label: const Text('Gestión de Roles de Usuario', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  
                  const SizedBox(height: 30),
                  const Text('Actividad Reciente (Materiales)', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 15),

                  StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance.collection('apuntes').orderBy('fecha_subida', descending: true).limit(5).snapshots(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
                      if (!snapshot.hasData || snapshot.data!.docs.isEmpty) return const Text('No hay actividad reciente.', style: TextStyle(color: Colors.grey));

                      return ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: snapshot.data!.docs.length,
                        itemBuilder: (context, index) {
                          var doc = snapshot.data!.docs[index].data() as Map<String, dynamic>;
                          return Card(
                            elevation: 1,
                            margin: const EdgeInsets.only(bottom: 8),
                            child: ListTile(
                              leading: const CircleAvatar(backgroundColor: Colors.blueAccent, child: Icon(Icons.upload, color: Colors.white, size: 20)),
                              title: Text(doc['nombre_archivo'] ?? 'Sin título', style: const TextStyle(fontWeight: FontWeight.w600)),
                              subtitle: Text('Subido por: ${doc['autor_nombre'] ?? 'Desconocido'}'),
                              trailing: const Text('Nuevo', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 12)),
                            ),
                          );
                        },
                      );
                    },
                  ),
                ],
              ),
            ),
    );
  }

  Widget _crearTarjetaKPI(String titulo, String valor, IconData icono, Color color) {
    return Expanded(
      child: Card(
        elevation: 2,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 8.0),
          child: Column(
            children: [
              Icon(icono, size: 30, color: color),
              const SizedBox(height: 10),
              Text(valor, style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: color)),
              const SizedBox(height: 5),
              Text(titulo, style: const TextStyle(fontSize: 12, color: Colors.grey)),
            ],
          ),
        ),
      ),
    );
  }
}