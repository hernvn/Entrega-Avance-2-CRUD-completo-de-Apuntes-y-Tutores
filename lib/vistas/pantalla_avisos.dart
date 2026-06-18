import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';

class PantallaAvisos extends StatelessWidget {
  const PantallaAvisos({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Avisos y Noticias"),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('avisos').orderBy('fecha', descending: true).snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          
          final avisos = snapshot.data!.docs;
          
          if (avisos.isEmpty) {
            return const Center(child: Text("No hay avisos recientes.", style: TextStyle(color: Colors.grey)));
          }

          return ListView.builder(
            itemCount: avisos.length,
            itemBuilder: (context, index) {
              final aviso = avisos[index];
              final data = aviso.data() as Map<String, dynamic>;
              
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                elevation: 2,
                child: ListTile(
                  title: Text(data['titulo'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text(data['mensaje'] ?? ''),
                  leading: const CircleAvatar(
                    backgroundColor: Colors.blueAccent,
                    child: Icon(Icons.notifications_active, color: Colors.white),
                  ),
                  trailing: data.containsKey('url') 
                      ? const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.blue) 
                      : null,
                  onTap: () async {
                    if (data.containsKey('url') && data['url'] != null && data['url'].toString().isNotEmpty) {
                      final Uri url = Uri.parse(data['url']);
                      
                      try {
                        // Intentamos abrir el enlace directamente sin consultar permisos previos
                        final bool exito = await launchUrl(url, mode: LaunchMode.externalApplication);
                        
                        if (!exito && context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('No se encontró una aplicación para abrir este archivo.')),
                          );
                        }
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Error al procesar el enlace del archivo.')),
                          );
                        }
                      }
                    } else {
                      // Si la notificación no tiene URL (notificaciones antiguas)
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Este aviso no contiene un archivo adjunto.')),
                      );
                    }
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}