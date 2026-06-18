import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'vistas/pantalla_splash.dart';
import 'connectivity_service.dart';
import 'vistas/pantalla_avisos.dart';


final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
bool abrirAvisosAlInicio = false;

const AndroidNotificationChannel channel = AndroidNotificationChannel(
  'high_importance_channel',
  'Notificaciones Importantes',
  description: 'Este canal se usa para notificaciones importantes.',
  importance: Importance.high,
);

Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  
  RemoteMessage? initialMessage = await FirebaseMessaging.instance.getInitialMessage();
  if (initialMessage != null) {
    abrirAvisosAlInicio = true;
  }

  FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
    Future.delayed(const Duration(milliseconds: 300), () {
      if (navigatorKey.currentState != null) {
        navigatorKey.currentState!.push(
          MaterialPageRoute(builder: (_) => const PantallaAvisos()),
        );
      }
    });
  });

  await initNotifications();
  runApp(const CampusSyncApp());
}

Future<void> initNotifications() async {
  FirebaseMessaging messaging = FirebaseMessaging.instance;
  await messaging.requestPermission(alert: true, badge: true, sound: true);

  const AndroidInitializationSettings initializationSettingsAndroid =
      AndroidInitializationSettings('@mipmap/ic_launcher');

  const InitializationSettings initializationSettings = InitializationSettings(
    android: initializationSettingsAndroid,
  );

  await flutterLocalNotificationsPlugin.initialize(
    initializationSettings,
    onDidReceiveNotificationResponse: (NotificationResponse details) {
      Future.delayed(const Duration(milliseconds: 100), () {
        if (navigatorKey.currentState != null) {
          navigatorKey.currentState!.push(
            MaterialPageRoute(builder: (_) => const PantallaAvisos()),
          );
        }
      });
    },
  );

  await flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(channel);

  FirebaseMessaging.onMessage.listen((RemoteMessage message) {
    RemoteNotification? notification = message.notification;
    AndroidNotification? android = message.notification?.android;

    if (notification != null && android != null) {
      flutterLocalNotificationsPlugin.show(
        notification.hashCode,
        notification.title,
        notification.body,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'high_importance_channel',
            'Notificaciones Importantes',
            channelDescription: 'Canal de avisos importantes',
            importance: Importance.high,
            priority: Priority.high,
            icon: '@mipmap/ic_launcher',
          ),
        ),
        payload: 'click_aviso',
      );
    }
  });
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
      navigatorKey: navigatorKey,
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
                          Icon(isOnline ? Icons.wifi : Icons.wifi_off, color: Colors.white, size: 14),
                          const SizedBox(width: 8),
                          Text(
                            isOnline ? 'CONECTADO' : 'SIN CONEXIÓN',
                            style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
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