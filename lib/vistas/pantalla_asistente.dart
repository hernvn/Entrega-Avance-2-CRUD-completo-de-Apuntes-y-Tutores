import 'package:flutter/material.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import '../api_key.dart';

class PantallaAsistente extends StatefulWidget {
  const PantallaAsistente({super.key});

  @override
  State<PantallaAsistente> createState() => _PantallaAsistenteState();
}

class _PantallaAsistenteState extends State<PantallaAsistente> {
  final TextEditingController _mensajeController = TextEditingController();
  final List<Map<String, String>> _historial = [];
  bool _cargando = false;
  late final GenerativeModel _modelo;
  late final ChatSession _chat;

  @override
  void initState() {
    super.initState();
    _modelo = GenerativeModel(
      model: 'gemini-2.5-flash',
      apiKey: geminiApiKey, 
      systemInstruction: Content.system(
        'Eres el Tutor IA oficial de CampusSync en la Universidad Autónoma. '
        'Tu especialidad es ayudar a los estudiantes a resolver dudas, priorizando explicaciones de Cálculo II y Álgebra. '
        'Sé claro, pedagógico, paso a paso y directo.'
      ),
    );
    _chat = _modelo.startChat();
  }

  Future<void> _enviarMensaje() async {
    if (_mensajeController.text.trim().isEmpty) return;
    final textoUsuario = _mensajeController.text.trim();

    setState(() {
      _historial.insert(0, {"rol": "user", "texto": textoUsuario});
      _cargando = true;
    });

    _mensajeController.clear();

    try {
      final respuesta = await _chat.sendMessage(Content.text(textoUsuario));
      setState(() {
        _historial.insert(0, {"rol": "ai", "texto": respuesta.text ?? 'Hubo un problema al generar la respuesta.'});
      });
    } catch (e) {
      setState(() {
        String mensajeError = "Error de conexión:\n$e";
        
        if (e.toString().contains('503') || e.toString().contains('high demand')) {
          mensajeError = "El Tutor IA está atendiendo a muchos estudiantes en este momento. Por favor, intenta de nuevo en un par de minutos.";
        }
        
        _historial.insert(0, {"rol": "error", "texto": mensajeError});
      });
    } finally {
      setState(() => _cargando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tutor IA CampusSync'),
        backgroundColor: Colors.blue.shade800,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              reverse: true,
              itemCount: _historial.length,
              itemBuilder: (context, index) {
                final msj = _historial[index];
                final esUsuario = msj["rol"] == "user";
                final esError = msj["rol"] == "error";

                return Align(
                  alignment: esUsuario ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: esError ? Colors.red.shade100 : (esUsuario ? Colors.blue.shade100 : Colors.white),
                      borderRadius: BorderRadius.circular(15),
                      border: esUsuario ? null : Border.all(color: Colors.grey.shade300),
                    ),
                    child: Text(msj["texto"]!, style: TextStyle(color: esError ? Colors.red : Colors.black87, fontSize: 15)),
                  ),
                );
              },
            ),
          ),
          if (_cargando) const Padding(padding: EdgeInsets.all(12.0), child: CircularProgressIndicator()),
          Container(
            padding: const EdgeInsets.all(12.0),
            color: Colors.white,
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _mensajeController,
                    decoration: InputDecoration(
                      hintText: 'Pregunta sobre Cálculo II, Álgebra o la app...',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(25)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 20),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                CircleAvatar(
                  backgroundColor: Colors.blue,
                  child: IconButton(icon: const Icon(Icons.send, color: Colors.white), onPressed: _cargando ? null : _enviarMensaje),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}