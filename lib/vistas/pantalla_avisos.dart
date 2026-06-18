import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PantallaAvisos extends StatefulWidget {
  const PantallaAvisos({super.key});

  @override
  State<PantallaAvisos> createState() => _PantallaAvisosState();
}

class _PantallaAvisosState extends State<PantallaAvisos> {
  List<String> _avisosLeidos = [];

  @override
  void initState() {
    super.initState();
    _cargarAvisosLeidos();
  }

  // Cumplimos el requisito de usar SharedPreferences (Taller 1)
  Future<void> _cargarAvisosLeidos() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _avisosLeidos = prefs.getStringList('avisos_leidos') ?? [];
    });
  }

  Future<void> _marcarComoLeido(String idAviso) async {
    if (!_avisosLeidos.contains(idAviso)) {
      final prefs = await SharedPreferences.getInstance();
      setState(() {
        _avisosLeidos.add(idAviso);
      });
      await prefs.setStringList('avisos_leidos', _avisosLeidos);
    }
  }

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
              final String avisoId = aviso.id;
              
              // Verificamos el ESTADO de la notificación (Taller 2)
              final bool estaLeido = _avisosLeidos.contains(avisoId);

              return Card(
                color: estaLeido ? Colors.white : Colors.blue.shade50,
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                elevation: estaLeido ? 1 : 3,
                child: ListTile(
                  title: Row(
                    children: [
                      Expanded(
                        child: Text(
                          data['titulo'] ?? '', 
                          style: TextStyle(
                            fontWeight: estaLeido ? FontWeight.normal : FontWeight.bold,
                            color: estaLeido ? Colors.black87 : Colors.black,
                          )
                        ),
                      ),
                      if (!estaLeido)
                        Container(
                          margin: const EdgeInsets.only(left: 8),
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.red,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Text('NUEVO', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                        )
                    ],
                  ),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 4.0),
                    child: Text(data['mensaje'] ?? ''),
                  ),
                  leading: CircleAvatar(
                    backgroundColor: estaLeido ? Colors.grey : Colors.blueAccent,
                    child: Icon(estaLeido ? Icons.notifications_none : Icons.notifications_active, color: Colors.white),
                  ),
                  trailing: data.containsKey('url') 
                      ? Icon(Icons.arrow_forward_ios, size: 16, color: estaLeido ? Colors.grey : Colors.blue) 
                      : null,
                  onTap: () async {
                    // Marcamos como leído localmente
                    _marcarComoLeido(avisoId);

                    if (data.containsKey('url') && data['url'] != null && data['url'].toString().isNotEmpty) {
                      final Uri url = Uri.parse(data['url']);
                      try {
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