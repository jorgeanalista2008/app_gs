import 'dart:convert';
import 'database_helper.dart';
import 'connectivity_service.dart';
import '../repositories/generic_repository.dart';

class SyncService {
  static final SyncService instance = SyncService._();
  final DatabaseHelper _db = DatabaseHelper.instance;

  SyncService._();

  /// Verifica respuestas guardadas y muestra estadísticas
  Future<Map<String, int>> verificarPendientes() async {
    try {
      final pendientes = await _db.getRespuestasPendientes();
      final completadas = pendientes.where((r) => r['sincronizado'] == 1).length;
      final sinEnviar = pendientes.where((r) => r['sincronizado'] == 0).length;

      print('📊 Estado de respuestas:');
      print('   ✅ Completadas: $completadas');
      print('   ⏳ Pendientes: $sinEnviar');

      return {
        'completadas': completadas,
        'pendientes': sinEnviar,
        'total': pendientes.length,
      };
    } catch (e) {
      print('❌ Error verificando pendientes: $e');
      return {'completadas': 0, 'pendientes': 0, 'total': 0};
    }
  }

  /// Descarga visitas y preguntas desde el servidor y las guarda localmente
  Future<Map<String, int>> descargarDatosFromServer() async {
    int visitasDescargadas = 0;
    int encuestasDescargadas = 0;
    int errores = 0;

    try {
      final conectado = await ConnectivityService.instance.isConnected();
      if (!conectado) {
        print('📴 Sin conexión para descargar datos');
        return {'visitas': 0, 'encuestas': 0, 'errores': 1};
      }

      print('📥 Descargando visitas desde el servidor...');
      final visitas = await GenericRepository.instance.getListOnline<Map<String, dynamic>>(
        path: '/salesperson/me/schedules',
        fromJson: (json) => json,
      );

      if (visitas.isNotEmpty) {
        await _db.guardarVisitas(visitas);
        visitasDescargadas = visitas.length;
        print('✅ $visitasDescargadas visitas guardadas localmente');

        for (var visita in visitas) {
          final visitaId = visita['id']?.toString();
          if (visitaId != null) {
            try {
              print('📥 Descargando preguntas para visita $visitaId...');
              final data = await GenericRepository.instance.getByIdOnline<Map<String, dynamic>>(
                path: '/salesperson/me/schedules/$visitaId/with-questions',
                fromJson: (json) => json,
              );

              if (data != null) {
                final questions = data['questions'] ?? data['questions_json'] ?? data;
                await _db.guardarEncuestaPreguntas(
                  id: data['id']?.toString() ?? visitaId,
                  visitId: visitaId,
                  salespersonId: data['salesperson_id']?.toString(),
                  customerId: data['customer_id']?.toString(),
                  questionsJson: jsonEncode(questions),
                );
                encuestasDescargadas++;
                print('✅ Preguntas guardadas para visita $visitaId');
              }
            } catch (e) {
              errores++;
              print('❌ Error descargando preguntas para visita $visitaId: $e');
            }
          }
        }
      }
    } catch (e) {
      errores++;
      print('❌ Error en descargarDatosFromServer: $e');
    }

    return {
      'visitas': visitasDescargadas,
      'encuestas': encuestasDescargadas,
      'errores': errores,
    };
  }

  /// Sube las respuestas pendientes al servidor y las marca como sincronizadas
  Future<Map<String, int>> marcarTodoSincronizado() async {
    int marcadas = 0;
    int errores = 0;

    try {
      final conectado = await ConnectivityService.instance.isConnected();
      if (!conectado) {
        print('📴 Sin conexión para subir datos');
        return {'marcadas': 0, 'errores': 1};
      }

      final pendientes = await _db.getRespuestasPendientes();
      print('📦 Subiendo ${pendientes.length} respuestas pendientes...');

      for (var respuesta in pendientes) {
        try {
          if (respuesta['sincronizado'] == 0) {
            final answersList = jsonDecode(respuesta['respuestas_json'] as String);
            
            final body = {
              'visit_id': respuesta['visit_id'],
              'latitude': respuesta['lat'],
              'longitude': respuesta['lng'],
              'photo_1': respuesta['foto1_path'], // base64 string
              'photo_2': respuesta['foto2_path'], // base64 string
              'answers': answersList,
            };

            print('📤 Enviando respuesta para visita ${respuesta['visit_id']}...');
            final response = await GenericRepository.instance.postOnline<Map<String, dynamic>>(
              path: '/salesperson/me/answers',
              body: body,
              fromJson: (json) => json,
            );

            if (response != null) {
              await _db.marcarRespuestaSincronizada(respuesta['id'] as int);
              await _db.actualizarEstadoVisita(
                respuesta['visit_id'] as String,
                'COMPLETED',
              );
              marcadas++;
              print('✅ Respuesta #${respuesta['id']} subida y sincronizada');
            } else {
              errores++;
              print('❌ API rechazó la respuesta #${respuesta['id']}');
            }
          }
        } catch (e) {
          errores++;
          print('❌ Error subiendo #${respuesta['id']}: $e');
        }
      }

      // Limpiar sincronizadas
      if (marcadas > 0) {
        await _db.eliminarRespuestasSincronizadas();
        await _db.limpiarDatosAntiguos();
      }

      print('📊 $marcadas subidas con éxito, $errores errores');
    } catch (e) {
      print('❌ Error en marcarTodoSincronizado: $e');
      errores++;
    }

    return {'marcadas': marcadas, 'errores': errores};
  }

  /// Obtiene todas las respuestas para revisión (admin)
  Future<List<Map<String, dynamic>>> getTodasLasRespuestas() async {
    try {
      final db = await _db.database;
      return await db.query('respuestas_pendientes', orderBy: 'fecha_creacion DESC');
    } catch (e) {
      return [];
    }
  }

  /// Obtiene respuestas de una visita específica
  Future<List<Map<String, dynamic>>> getRespuestasDeVisita(String visitId) async {
    try {
      final db = await _db.database;
      return await db.query(
        'respuestas_pendientes',
        where: 'visit_id = ?',
        whereArgs: [visitId],
        orderBy: 'fecha_creacion DESC',
      );
    } catch (e) {
      return [];
    }
  }

  /// Limpia todas las respuestas (peligroso, solo admin)
  Future<bool> limpiarTodo() async {
    try {
      final db = await _db.database;
      await db.delete('respuestas_pendientes');
      print('🗑️ Todas las respuestas eliminadas');
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Obtiene estadísticas generales
  Future<Map<String, dynamic>> getEstadisticas() async {
    try {
      final db = await _db.database;

      final totalVisitas = await db.rawQuery('SELECT COUNT(*) as total FROM visitas');
      final visitasPendientes = await db.rawQuery("SELECT COUNT(*) as total FROM visitas WHERE status = 'PENDING'");
      final visitasCompletadas = await db.rawQuery("SELECT COUNT(*) as total FROM visitas WHERE status = 'COMPLETED'");
      final totalRespuestas = await db.rawQuery('SELECT COUNT(*) as total FROM respuestas_pendientes');
      final totalClientes = await db.rawQuery('SELECT COUNT(*) as total FROM clientes');

      return {
        'visitas_total': totalVisitas.first['total'] ?? 0,
        'visitas_pendientes': visitasPendientes.first['total'] ?? 0,
        'visitas_completadas': visitasCompletadas.first['total'] ?? 0,
        'respuestas_total': totalRespuestas.first['total'] ?? 0,
        'clientes_total': totalClientes.first['total'] ?? 0,
      };
    } catch (e) {
      return {};
    }
  }

  /// Inicia el servicio (sin auto-sync de red)
  static void iniciar() {
    print('📦 SyncService local iniciado');
    instance.verificarPendientes();
  }
}