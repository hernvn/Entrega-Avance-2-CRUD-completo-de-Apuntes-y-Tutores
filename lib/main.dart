import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'vistas/pantalla_splash.dart';
import 'connectivity_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(); 
  runApp(const CampusSyncApp());
}

class CampusSyncApp extends StatefulWidget {
  const CampusSyncApp({super.key});

  @override
  State<CampusSyncApp> createState() => _CampusSyncAppState();
}

class _CampusSyncAppState extends State<CampusSyncApp> {
  final ConnectivityService _connectivityService = ConnectivityService();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'CampusSync',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      builder: (context, child) {
        return StreamBuilder<bool>(
          stream: _connectivityService.connectivityStream,
          initialData: true, 
          builder: (context, snapshot) {
            final isOnline = snapshot.data ?? true;

            return Scaffold(
             
              body: SafeArea(
                child: Column(
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      
                      color: isOnline ? Colors.green.shade700 : Colors.red.shade700,
                      width: double.infinity,
                      height: 28, 
                      alignment: Alignment.center,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            isOnline ? Icons.wifi : Icons.wifi_off,
                            color: Colors.white,
                            size: 14,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            isOnline 
                                ? 'CONECTADO' 
                                : 'SIN CONEXIÓN',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(child: child ?? const SizedBox.shrink()),
                  ],
                ),
              ),
            );
          },
        );
      },
      home: const PantallaSplash(),
    );
  }

  @override
  void dispose() {
    _connectivityService.dispose();
    super.dispose();
  }
}