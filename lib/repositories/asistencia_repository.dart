import 'dart:convert';
import 'package:uuid/uuid.dart';
import '../services/database_helper.dart';
import '../services/auth_service.dart';
import '../services/sync_queue_service.dart';
import '../services/location_service.dart';

enum TipoAsistencia { entrada, salida }

extension TipoAsistenciaX on TipoAsistencia {
  String get apiValue => this == TipoAsistencia.entrada ? 'ENTRADA' : 'SALIDA';
  String get label => this == TipoAsistencia.entrada ? 'Entrada' : 'Salida';
}

class AsistenciaDia {
  final Map<String, dynamic>? entrada;
  final Map<String, dynamic>? salida;

  const AsistenciaDia({this.entrada, this.salida});

  bool get tieneEntrada => entrada != null;
  bool get tieneSalida => salida != null;
  bool get jornadaCompleta => tieneEntrada && tieneSalida;

  /// Qué le toca marcar ahora — null si ya cerró la jornada.
  TipoAsistencia? get siguiente {
    if (!tieneEntrada) return TipoAsistencia.entrada;
    if (!tieneSalida) return TipoAsistencia.salida;
    return null;
  }
}

/// Marcaje de jornada del vendedor foráneo.
///
/// Offline-first a propósito: la marca se guarda SIEMPRE en SQLite primero y
/// se encola para subir. Un vendedor que arranca su ruta sin señal a las 8am
/// no puede quedarse sin marcar — la hora que vale es la del dispositivo
/// (`recorded_at`), no la de llegada al servidor.
class AsistenciaRepository {
  static final AsistenciaRepository instance = AsistenciaRepository._();
  AsistenciaRepository._();

  final DatabaseHelper _db = DatabaseHelper.instance;
  final AuthService _auth = AuthService.instance;
  final _uuid = const Uuid();

  static const String _entityType = 'asistencia';

  /// Marca la asistencia local como sincronizada cuando la cola confirma el
  /// push. Sin esto la marca se sube bien pero la UI sigue mostrando el ícono
  /// de "pendiente de subir" para siempre. Llamar una vez desde main.dart.
  static void registerSyncHandlers() {
    SyncQueueService.instance.registerSuccessHandler(
      _entityType,
      _onAsistenciaPushSuccess,
    );
  }

  static Future<void> _onAsistenciaPushSuccess(
    Map<String, dynamic> operation,
    String responseBody,
  ) async {
    final localId = operation['entity_local_id']?.toString();
    if (localId == null) return;

    String? serverId;
    try {
      final decoded = jsonDecode(responseBody);
      if (decoded is Map<String, dynamic>) {
        final data = decoded['data'] is Map<String, dynamic>
            ? decoded['data'] as Map<String, dynamic>
            : decoded;
        serverId = data['id']?.toString();
      }
    } catch (_) {}

    try {
      final db = await DatabaseHelper.instance.database;
      await db.update(
        'asistencia',
        {'sincronizado': 1, if (serverId != null) 'server_id': serverId},
        where: 'id = ?',
        whereArgs: [localId],
      );
    } catch (e) {
      print('⚠️ [Asistencia] no se pudo marcar como sincronizada: $e');
    }
  }

  /// Día local (America/Caracas, UTC-4) — mismo criterio que el backend,
  /// para que una marca de las 7:58am no caiga en el día anterior.
  String _localDay(DateTime utc) {
    final local = utc.subtract(const Duration(hours: 4));
    return '${local.year.toString().padLeft(4, '0')}-'
        '${local.month.toString().padLeft(2, '0')}-'
        '${local.day.toString().padLeft(2, '0')}';
  }

  Future<AsistenciaDia> getHoy() async {
    try {
      final db = await _db.database;
      final userId = _auth.userId;
      final hoy = _localDay(DateTime.now().toUtc());

      final rows = await db.query(
        'asistencia',
        where: 'user_id = ? AND local_day = ?',
        whereArgs: [userId, hoy],
        orderBy: 'recorded_at ASC',
      );

      Map<String, dynamic>? entrada;
      Map<String, dynamic>? salida;
      for (final r in rows) {
        if (r['tipo'] == 'ENTRADA') entrada ??= r;
        if (r['tipo'] == 'SALIDA') salida ??= r;
      }

      return AsistenciaDia(entrada: entrada, salida: salida);
    } catch (e) {
      print('❌ [Asistencia] Error leyendo asistencia de hoy: $e');
      return const AsistenciaDia();
    }
  }

  /// Marca entrada o salida. Devuelve null si se guardó bien, o el mensaje
  /// de error si la marca no era válida (doble entrada, salida sin entrada).
  Future<String?> marcar(TipoAsistencia tipo) async {
    final userId = _auth.userId;
    if (userId == null) return 'No hay sesión activa';

    final hoy = await getHoy();
    if (tipo == TipoAsistencia.entrada && hoy.tieneEntrada) {
      return 'Ya marcaste tu entrada hoy';
    }
    if (tipo == TipoAsistencia.salida && !hoy.tieneEntrada) {
      return 'Debes marcar entrada antes de la salida';
    }
    if (tipo == TipoAsistencia.salida && hoy.tieneSalida) {
      return 'Ya marcaste tu salida hoy';
    }

    final ahora = DateTime.now().toUtc();
    final localId = _uuid.v4();

    // La ubicación es un extra: si el GPS tarda o falla, la marca igual se
    // guarda — perder el marcaje de jornada por no tener fix sería peor.
    double? lat;
    double? lng;
    try {
      final pos = await LocationService.getCurrentLocation();
      lat = pos?.latitude;
      lng = pos?.longitude;
    } catch (_) {}

    try {
      final db = await _db.database;
      await db.insert('asistencia', {
        'id': localId,
        'user_id': userId,
        'tipo': tipo.apiValue,
        'recorded_at': ahora.toIso8601String(),
        'local_day': _localDay(ahora),
        'lat': lat,
        'lng': lng,
        'sincronizado': 0,
        'created_at': ahora.toIso8601String(),
      });

      final userLocal = await _db.getUsuario(userId);
      await SyncQueueService.instance.enqueue(
        entityType: 'asistencia',
        entityLocalId: localId,
        operation: 'create',
        httpMethod: 'POST',
        endpoint: '/salesperson/auth/attendance',
        payload: {
          'email': userLocal?['username'],
          'password': userLocal?['password'],
          'type': tipo.apiValue,
          'recorded_at': ahora.toIso8601String(),
          if (lat != null) 'latitude': lat,
          if (lng != null) 'longitude': lng,
        },
      );

      print('✅ [Asistencia] ${tipo.label} marcada: ${ahora.toIso8601String()}');
      return null;
    } catch (e) {
      print('❌ [Asistencia] Error marcando ${tipo.label}: $e');
      return 'No se pudo guardar la marca: $e';
    }
  }

  /// Historial local para que el vendedor revise sus jornadas.
  Future<List<Map<String, dynamic>>> getHistorial({int dias = 30}) async {
    try {
      final db = await _db.database;
      final desde = _localDay(
        DateTime.now().toUtc().subtract(Duration(days: dias)),
      );
      return await db.query(
        'asistencia',
        where: 'user_id = ? AND local_day >= ?',
        whereArgs: [_auth.userId, desde],
        orderBy: 'recorded_at DESC',
      );
    } catch (e) {
      print('❌ [Asistencia] Error leyendo historial: $e');
      return [];
    }
  }
}
