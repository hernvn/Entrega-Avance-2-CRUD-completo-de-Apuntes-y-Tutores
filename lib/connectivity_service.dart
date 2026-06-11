import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';

class ConnectivityService {
  final _connectivityController = StreamController<bool>.broadcast();
  
  Stream<bool> get connectivityStream => _connectivityController.stream;

  ConnectivityService() {
    Connectivity().onConnectivityChanged.listen((List<ConnectivityResult> results) {
      if (results.contains(ConnectivityResult.none)) {
        _connectivityController.add(false);
      } else {
        _connectivityController.add(true); 
      }
    });
  }

  Future<bool> checkCurrentConnection() async {
    final results = await Connectivity().checkConnectivity();
    return !results.contains(ConnectivityResult.none);
  }

  void dispose() {
    _connectivityController.close();
  }
}