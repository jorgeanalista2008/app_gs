import 'package:connectivity_plus/connectivity_plus.dart';

class ConnectivityService {
  static Future<bool> isConnected() async {
    try {
      final result = await Connectivity().checkConnectivity();
      return result == ConnectivityResult.mobile ||
             result == ConnectivityResult.wifi ||
             result == ConnectivityResult.ethernet;
    } catch (e) {
      // Si falla la detección, asumir que hay conexión
      return true;
    }
  }

  static Stream<ConnectivityResult> get onConnectivityChanged =>
      Connectivity().onConnectivityChanged;
}