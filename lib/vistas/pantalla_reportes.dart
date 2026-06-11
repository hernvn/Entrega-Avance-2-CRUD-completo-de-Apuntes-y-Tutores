import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';

class PantallaReportes extends StatelessWidget {
  const PantallaReportes({super.key});

  Future<void> _ignorarReporte(BuildContext context, String reporteId) async {
    try {
      // Si el reporte es falso, solo borramos la alerta, el archivo se queda intacto
      await FirebaseFirestore.instance.collection('reportes').doc(reporteId).delete();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Reporte ignorado y eliminado.'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _ocultarMaterialYReporte(BuildContext context, String reporteId, String apunteId) async {
    try {
      // 1. En lugar de borrar, actualizamos el documento para ocultarlo (Soft Delete)
      await FirebaseFirestore.instance.collection('apuntes').doc(apunteId).update({
        'visible': false,
        'ocultadoPor': 'Moderador',
        'fechaOculto': FieldValue.serverTimestamp(),
      });

      // 2. Borramos el reporte de la bandeja porque ya está resuelto
      await FirebaseFirestore.instance.collection('reportes').doc(reporteId).delete();

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Material ocultado del sistema exitosamente.'), backgroundColor: Colors.orange),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al ocultar: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _verArchivo(BuildContext context, String apunteId) async {
    try {
      final doc = await FirebaseFirestore.instance.collection('apuntes').doc(apunteId).get();
      
      // Asegúrate de que el campo donde guardas el link en Firebase se llame 'url'
      if (doc.exists && doc.data()!.containsKey('url')) {
        final url = Uri.parse(doc['url']);
        if (await canLaunchUrl(url)) {
          await launchUrl(url, mode: LaunchMode.externalApplication);
        } else {
          throw 'No se pudo abrir el enlace del dispositivo.';
        }
      } else {
        throw 'El archivo original ya fue eliminado o no tiene enlace.';
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al abrir evidencia: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Bandeja de Reportes', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.red.shade800,
        foregroundColor: Colors.white,
      ),
      backgroundColor: Colors.grey.shade100,
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('reportes').orderBy('fechaReporte', descending: true).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.check_circle_outline, size: 80, color: Colors.green),
                  SizedBox(height: 16),
                  Text('Todo está en orden', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.blueGrey)),
                  Text('No hay reportes pendientes de revisión.', style: TextStyle(color: Colors.grey)),
                ],
              ),
            );
          }

          final reportes = snapshot.data!.docs;

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: reportes.length,
            itemBuilder: (context, index) {
              var reporte = reportes[index].data() as Map<String, dynamic>;
              String reporteId = reportes[index].id;
              String apunteId = reporte['apunteId'] ?? '';

              return Card(
                elevation: 3,
                margin: const EdgeInsets.only(bottom: 15),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 30),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              reporte['nombreArchivo'] ?? 'Archivo desconocido',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                          ),
                        ],
                      ),
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 8.0),
                        child: Divider(),
                      ),
                      const Text('Motivo del reporte por el estudiante:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.grey)),
                      const SizedBox(height: 5),
                      Text(reporte['motivo'] ?? 'Sin motivo especificado', style: const TextStyle(fontSize: 15, fontStyle: FontStyle.italic)),
                      const SizedBox(height: 20),
                      Wrap(
                        spacing: 8.0,
                        runSpacing: 8.0,
                        alignment: WrapAlignment.end,
                        children: [
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.blue.shade700, foregroundColor: Colors.white),
                            onPressed: () => _verArchivo(context, apunteId),
                            icon: const Icon(Icons.picture_as_pdf),
                            label: const Text('Ver PDF'),
                          ),
                          OutlinedButton.icon(
                            onPressed: () => _ignorarReporte(context, reporteId),
                            icon: const Icon(Icons.visibility_off, color: Colors.grey),
                            label: const Text('Ignorar', style: TextStyle(color: Colors.grey)),
                          ),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange.shade800, foregroundColor: Colors.white),
                            onPressed: () => _ocultarMaterialYReporte(context, reporteId, apunteId),
                            icon: const Icon(Icons.delete_sweep),
                            label: const Text('Ocultar'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}