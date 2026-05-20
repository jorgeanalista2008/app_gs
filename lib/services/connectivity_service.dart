import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';

class ConnectivityService {
  static final ConnectivityService instance = ConnectivityService._();
  ConnectivityService._();

  final _connectivity = Connectivity();
  final _controller = StreamController<ConnectivityResult>.broadcast();

  /// Stream que emite el estado de conexión
  Stream<ConnectivityResult> get onConnectivityChanged => _controller.stream;

  /// Verifica si hay conexión ahora
  Future<bool> isConnected() async {
    try {
      final result = await _connectivity.checkConnectivity();
      return result == ConnectivityResult.mobile ||
             result == ConnectivityResult.wifi ||
             result == ConnectivityResult.ethernet;
    } catch (e) {
      return false;
    }
  }

  /// Inicia el listener de conectividad
  void iniciarMonitor() {
    _connectivity.onConnectivityChanged.listen((ConnectivityResult result) {
      _controller.add(result);
      final conectado = result == ConnectivityResult.mobile ||
                        result == ConnectivityResult.wifi ||
                        result == ConnectivityResult.ethernet;
      print(conectado ? '🌐 Conectado a internet' : '📴 Sin conexión a internet');
    });
  }

  void dispose() {
    _controller.close();
  }
}