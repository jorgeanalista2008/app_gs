import 'dart:convert';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'connectivity_service.dart';
import 'database_helper.dart';
import '../repositories/encuesta_repository.dart';

class SyncService {
  static final SyncService instance = SyncService._();
  final DatabaseHelper _db = DatabaseHelper.instance;
  final EncuestaRepository _encuestaRepo = EncuestaRepository();

  SyncService._();

  Future<Map<String, int>> sincronizarPendientes() async {
    int sincronizadas = 0;
    int errores = 0;

    try {
      final conectado = await ConnectivityService.isConnected();
      if (!conectado) {
        print('📴 Sin conexión. No se puede sincronizar.');
        return {'sincronizadas': 0, 'errores': 0};
      }

      final pendientes = await _db.getPendientes();
      print('🔄 Sincronizando ${pendientes.length} encuestas pendientes...');

      for (var encuesta in pendientes) {
        try {
          final respuestas = jsonDecode(encuesta['respuestas'] as String);
          final visitId = encuesta['visit_id'] as String;

          final exito = await _encuestaRepo.enviarEncuesta(
            visitId: visitId,
            respuestas: List<Map<String, dynamic>>.from(respuestas),
          );

          if (exito) {
            await _db.marcarSincronizado(encuesta['id'] as int);
            sincronizadas++;
            print('✅ Encuesta #${encuesta['id']} sincronizada');
          } else {
            errores++;
          }
        } catch (e) {
          errores++;
        }
      }
    } catch (e) {
      print('❌ Error: $e');
    }

    return {'sincronizadas': sincronizadas, 'errores': errores};
  }

  static void iniciarAutoSync() {
    ConnectivityService.onConnectivityChanged.listen((ConnectivityResult result) async {
      final conectado = result == ConnectivityResult.mobile ||
                        result == ConnectivityResult.wifi;
      if (conectado) {
        print('🌐 Conexión recuperada. Iniciando sincronización...');
        await instance.sincronizarPendientes();
      }
    });
  }
}