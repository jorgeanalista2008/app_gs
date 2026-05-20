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

  /// Sincroniza respuestas pendientes y limpia
  Future<Map<String, int>> sincronizarPendientes() async {
    int sincronizadas = 0;
    int errores = 0;

    try {
      final conectado = await ConnectivityService.instance.isConnected();
      if (!conectado) {
        print('📴 Sin conexión. No se puede sincronizar.');
        return {'sincronizadas': 0, 'errores': 0};
      }

      final pendientes = await _db.getRespuestasPendientes();
      print('🔄 Sincronizando ${pendientes.length} respuestas pendientes...');

      for (var respuesta in pendientes) {
        try {
          final respuestasJson = jsonDecode(respuesta['respuestas_json'] as String);
          final visitId = respuesta['visit_id'] as String;

          final exito = await _encuestaRepo.enviarEncuesta(
            visitId: visitId,
            respuestas: List<Map<String, dynamic>>.from(respuestasJson),
          );

          if (exito) {
            await _db.marcarRespuestaSincronizada(respuesta['id'] as int);
            // Actualizar estado de la visita a COMPLETED
            await _db.actualizarEstadoVisita(visitId, 'COMPLETED');
            sincronizadas++;
            print('✅ Respuesta #${respuesta['id']} sincronizada');
          } else {
            errores++;
            print('❌ Error sincronizando #${respuesta['id']}');
          }
        } catch (e) {
          errores++;
          print('❌ Error: $e');
        }
      }

      // Limpiar respuestas sincronizadas
      if (sincronizadas > 0) {
        final eliminadas = await _db.eliminarRespuestasSincronizadas();
        print('🗑️ $eliminadas respuestas eliminadas de la BD local');
      }

      print('📊 Resultado: $sincronizadas sincronizadas, $errores errores');
    } catch (e) {
      print('❌ Error en sincronización: $e');
    }

    return {'sincronizadas': sincronizadas, 'errores': errores};
  }

  /// Sincroniza todo: clientes, visitas, encuestas
  Future<void> sincronizarTodo({
    required List<Map<String, dynamic>> clientes,
    required List<Map<String, dynamic>> visitas,
  }) async {
    // Guardar clientes
    if (clientes.isNotEmpty) {
      await _db.guardarClientes(clientes);
      print('💾 ${clientes.length} clientes guardados localmente');
    }

    // Guardar visitas
    if (visitas.isNotEmpty) {
      await _db.guardarVisitas(visitas);
      print('💾 ${visitas.length} visitas guardadas localmente');
    }

    // Intentar sincronizar respuestas pendientes
    await sincronizarPendientes();

    // Limpiar datos antiguos
    await _db.limpiarDatosAntiguos();
  }

      static void iniciarAutoSync() {
        ConnectivityService.instance.onConnectivityChanged.listen((ConnectivityResult result) async {
          final conectado = result == ConnectivityResult.mobile ||
                            result == ConnectivityResult.wifi;
          if (conectado) {
            print('🌐 Conexión recuperada. Iniciando sincronización...');
            await instance.sincronizarPendientes();
          }
        });
      }
}