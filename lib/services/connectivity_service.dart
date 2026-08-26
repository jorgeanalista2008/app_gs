import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:http/http.dart' as http;

import '../core/env.dart';
import 'sync_service.dart';

class ConnectivityService {
  static final ConnectivityService instance = ConnectivityService._();
  ConnectivityService._();

  final _connectivity = Connectivity();
  final _controller = StreamController<ConnectivityResult>.broadcast();

  /// Stream que emite el estado de conexión
  Stream<ConnectivityResult> get onConnectivityChanged => _controller.stream;

  /// Verifica si hay conexión ahora.
  /// Se considera "conectado" cualquier resultado distinto de `none`
  /// (en vez de una lista blanca de tipos), ya que connectivity_plus también
  /// puede reportar `vpn`, `bluetooth` u `other` en dispositivos con VPN
  /// (NextDNS, bloqueadores de anuncios, DNS privado, etc.) — casos con
  /// internet real que antes se marcaban incorrectamente como offline.
  ///
  /// Reintenta un par de veces antes de dar por offline: `checkConnectivity()`
  /// puede devolver `none` con el dispositivo ya conectado — el canal de
  /// plataforma tarda en inicializar en arranque en frío, o Android retrasa
  /// el callback en Doze/App Standby. Confirmado en un Pixel 6 Pro con wifi Y
  /// datos móviles ya validados por Android (`dumpsys connectivity`): esto
  /// dejaba la sync completa (preguntas, packs de encuesta) sin correr nunca.
  ///
  /// Si los 3 intentos siguen dando `none`, se hace una prueba de red real
  /// (HEAD al propio backend) antes de concluir que sí está offline — un
  /// falso negativo del plugin no puede fingir una respuesta HTTP real.
  Future<bool> isConnected() async {
    for (var attempt = 0; attempt < 3; attempt++) {
      try {
        final result = await _connectivity.checkConnectivity();
        if (result != ConnectivityResult.none) {
          return true;
        }
      } catch (e) {
        // Reintenta igual — puede ser el mismo problema de inicialización.
      }
      if (attempt < 2) {
        await Future.delayed(const Duration(milliseconds: 400));
      }
    }
    return _probeRealConnectivity();
  }

  Future<bool> _probeRealConnectivity() async {
    try {
      final response = await http
          .head(Uri.parse(Env.apiBaseUrl))
          .timeout(const Duration(seconds: 4));
      return response.statusCode > 0;
    } catch (e) {
      return false;
    }
  }

  /// Inicia el listener de conectividad
  void iniciarMonitor() {
    _connectivity.onConnectivityChanged.listen((ConnectivityResult result) {
      _controller.add(result);
      final conectado = result != ConnectivityResult.none;
      print(conectado ? '🌐 Conectado a internet' : '📴 Sin conexión a internet');
      if (conectado) {
        print('⚡ [ConnectivityService] Red detectada/recuperada → Ejecutando sincronización automática...');
        SyncService.instance.ejecutarSincronizacionCompleta();
      }
    });
  }

  void dispose() {
    _controller.close();
  }
}