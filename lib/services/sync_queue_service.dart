import 'dart:async';
import 'dart:convert';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:sqflite/sqflite.dart';
import 'database_helper.dart';
import 'connectivity_service.dart';
import 'sync_service.dart';
import '../repositories/generic_repository.dart';

/// Cola de operaciones offline → API con retry exponencial.
///
/// Flujo:
/// 1. Repositorios llaman a [enqueue] tras escribir en SQLite.
/// 2. [drain] corre periódicamente y al recuperar red:
///    - Toma filas `status='pending'` con `next_retry_at <= now`.
///    - Ejecuta HTTP vía [GenericRepository.executeRequest].
///    - Éxito → `status='success'` + guarda respuesta del servidor.
///    - Fallo → incrementa `attempts`, backoff exponencial, o `failed_permanent` al máximo.
/// 3. 401 dispara re-auth con credenciales locales una vez por drain.
class SyncQueueService {
  static final SyncQueueService instance = SyncQueueService._();
  SyncQueueService._();

  final DatabaseHelper _db = DatabaseHelper.instance;
  final GenericRepository _repo = GenericRepository.instance;
  final ConnectivityService _connectivity = ConnectivityService.instance;

  StreamSubscription<ConnectivityResult>? _connSub;
  Timer? _periodicTimer;
  bool _draining = false;
  bool _reauthTriedThisDrain = false;

  final StreamController<bool> _syncingController = StreamController<bool>.broadcast();
  Stream<bool> get syncingStream => _syncingController.stream;
  bool get isDraining => _draining;

  /// Callbacks ejecutados tras éxito de push.
  /// Firma: `(operationRow, responseBody) => Future<void>`.
  /// Keyed por `entity_type` para que cada repositorio sólo reciba sus eventos.
  final Map<String, List<Future<void> Function(Map<String, dynamic>, String)>>
      _successHandlers = {};

  void registerSuccessHandler(
    String entityType,
    Future<void> Function(Map<String, dynamic> operation, String responseBody)
        handler,
  ) {
    _successHandlers.putIfAbsent(entityType, () => []).add(handler);
  }

  /// Backoff: 30s, 2m, 8m, 30m, 30m, ... tope 30m.
  static const List<int> _backoffSeconds = [30, 120, 480, 1800];
  static const int _defaultMaxAttempts = 10;
  static const Duration _periodicInterval = Duration(minutes: 2);

  /// Listeners para que la UI reaccione a cambios de cola.
  final StreamController<int> _pendingCountController =
      StreamController<int>.broadcast();
  Stream<int> get pendingCountStream => _pendingCountController.stream;

  /// Genera un dedup_key único para la operación (uuid v4 simple).
  /// Se pasa al backend en el body como `client_dedup_key` — si el mismo
  /// key llega dos veces, el backend devuelve la fila existente en vez de
  /// crear un duplicado. Esencial para reintentos tras timeout de red.
  String _newDedupKey() {
    final rand = DateTime.now().microsecondsSinceEpoch;
    final r = rand.toRadixString(16).padLeft(12, '0');
    // 32 hex chars → simula uuid sin dependencia extra.
    final b = List<int>.generate(
      12,
      (i) => (rand ^ (rand >> (i * 3))) & 0xff,
    ).map((n) => n.toRadixString(16).padLeft(2, '0')).join();
    return '$r-$b'.substring(0, 32);
  }

  /// Encola una operación. Devuelve el id local de la operación.
  Future<int> enqueue({
    required String entityType,
    String? entityLocalId,
    required String operation,
    required String httpMethod,
    required String endpoint,
    Map<String, dynamic>? payload,
    int maxAttempts = _defaultMaxAttempts,
  }) async {
    final db = await _db.database;
    final now = DateTime.now().toUtc().toIso8601String();

    // Solo POST necesita idempotency key (crea recursos nuevos).
    // Si el caller no lo puso, generamos uno y lo inyectamos en el payload
    // como `client_dedup_key`. Backend lo lee y bloquea duplicados.
    Map<String, dynamic>? finalPayload = payload;
    if (httpMethod.toUpperCase() == 'POST' && payload != null) {
      finalPayload = Map<String, dynamic>.from(payload);
      finalPayload.putIfAbsent('client_dedup_key', () => _newDedupKey());
    }

    final id = await db.insert('pending_operations', {
      'entity_type': entityType,
      'entity_local_id': entityLocalId,
      'operation': operation,
      'http_method': httpMethod.toUpperCase(),
      'endpoint': endpoint,
      'payload_json': finalPayload == null ? null : jsonEncode(finalPayload),
      'attempts': 0,
      'max_attempts': maxAttempts,
      'next_retry_at': now,
      'status': 'pending',
      'created_at': now,
      'updated_at': now,
    });
    print('📥 [SyncQueue] enqueued #$id $httpMethod $endpoint ($entityType)');
    await _emitCount();
    return id;
  }

  /// Inicia drain automático: dispara cuando vuelve la red + timer cada 2 min.
  void start() {
    // Reset de operaciones colgadas por crash: cualquier fila en
    // status='in_progress' al arrancar la app volvió porque la instancia
    // anterior murió a mitad de request. Vuelven a 'pending' para que el
    // próximo drain las reintente (con dedup_key el backend evita duplicar).
    _resetInProgressOnBoot();

    _connSub ??= _connectivity.onConnectivityChanged.listen((result) {
      // Igual que ConnectivityService.isConnected(): cualquier resultado
      // distinto de `none` cuenta como online (vpn/bluetooth/other también
      // son conexiones reales en dispositivos con VPN o DNS privado). Antes
      // solo se reconocían mobile/wifi/ethernet, así que el auto-sync nunca
      // se disparaba al reconectar en esos dispositivos.
      final online = result != ConnectivityResult.none;
      if (online) {
        print('🔄 [SyncQueue] red recuperada → ejecutarSincronizacionCompleta');
        SyncService.instance.ejecutarSincronizacionCompleta();
      }
    });
    _periodicTimer ??= Timer.periodic(_periodicInterval, (_) => SyncService.instance.intentarSubirDatos());
    // Sincronización inicial al arrancar (si hay red).
    SyncService.instance.ejecutarSincronizacionCompleta();
  }

  Future<void> _resetInProgressOnBoot() async {
    try {
      final db = await _db.database;
      final now = DateTime.now().toUtc().toIso8601String();
      final n = await db.update(
        'pending_operations',
        {'status': 'pending', 'next_retry_at': now, 'updated_at': now},
        where: "status = 'in_progress'",
      );
      if (n > 0) {
        print('♻️  [SyncQueue] reset $n operaciones in_progress colgadas');
      }
    } catch (e) {
      print('⚠️  [SyncQueue] reset in_progress falló: $e');
    }
  }

  void stop() {
    _connSub?.cancel();
    _connSub = null;
    _periodicTimer?.cancel();
    _periodicTimer = null;
  }

  /// Drena operaciones pendientes listas para reintento.
  Future<void> drain({bool force = false}) async {
    if (_draining) return;
    if (!force && !await _connectivity.isConnected()) {
      print('📴 [SyncQueue] offline, skip drain');
      return;
    }
    _draining = true;
    _syncingController.add(true);
    _reauthTriedThisDrain = false;
    try {
      final db = await _db.database;
      final nowIso = DateTime.now().toUtc().toIso8601String();
      final rows = await db.query(
        'pending_operations',
        where: "status = 'pending' AND next_retry_at <= ?",
        whereArgs: [nowIso],
        orderBy: 'created_at ASC',
        limit: 50,
      );

      if (rows.isEmpty) {
        print('✅ [SyncQueue] cola vacía');
        return;
      }
      print('🔁 [SyncQueue] procesando ${rows.length} operaciones');
      for (final row in rows) {
        await _processRow(row);
      }
    } catch (e) {
      print('❌ [SyncQueue] drain error: $e');
    } finally {
      _draining = false;
      _syncingController.add(false);
      await _emitCount();
    }
  }

  Future<void> _processRow(Map<String, dynamic> row) async {
    final id = row['id'] as int;
    final method = row['http_method'] as String;
    final endpoint = row['endpoint'] as String;
    final payloadJson = row['payload_json'] as String?;
    final attempts = (row['attempts'] as int?) ?? 0;
    final maxAttempts = (row['max_attempts'] as int?) ?? _defaultMaxAttempts;

    Map<String, dynamic>? payload;
    if (payloadJson != null && payloadJson.isNotEmpty) {
      try {
        payload = jsonDecode(payloadJson) as Map<String, dynamic>;
      } catch (e) {
        await _markFailedPermanent(id, 'payload JSON inválido: $e');
        return;
      }
    }

    await _setInProgress(id);

    try {
      final result = await _repo.executeRequest(
        method: method,
        endpoint: endpoint,
        payload: payload,
      );

      // 2xx → éxito
      if (result.statusCode >= 200 && result.statusCode < 300) {
        await _markSuccess(id, result.body);
        print('✅ [SyncQueue] #$id $method $endpoint OK (${result.statusCode})');
        await _invokeSuccessHandlers(row, result.body);
        return;
      }

      // 401 → re-auth y reintento inmediato (una vez por drain)
      if (result.statusCode == 401 && !_reauthTriedThisDrain) {
        _reauthTriedThisDrain = true;
        print('🔑 [SyncQueue] 401 — intentando re-auth');
        final ok = await SyncService.instance.authenticateOnline();
        if (ok) {
          // Reauth exitosa: reintenta inmediato sin gastar un intento.
          await _retryNowWithoutIncrement(id);
          return;
        }
      }

      // 4xx (no 401) → fallo permanente, no tiene sentido reintentar
      if (result.statusCode >= 400 &&
          result.statusCode < 500 &&
          result.statusCode != 401 &&
          result.statusCode != 408 &&
          result.statusCode != 429) {
        await _markFailedPermanent(id, 'HTTP ${result.statusCode}: ${result.body}');
        return;
      }

      // 5xx, 401 sin reauth, 408, 429 → backoff
      await _scheduleRetry(
        id,
        attempts,
        maxAttempts,
        'HTTP ${result.statusCode}: ${_truncate(result.body, 200)}',
      );
    } catch (e) {
      // Timeout/red → backoff
      await _scheduleRetry(id, attempts, maxAttempts, e.toString());
    }
  }

  Future<void> _invokeSuccessHandlers(
    Map<String, dynamic> row,
    String responseBody,
  ) async {
    final entityType = row['entity_type'] as String?;
    if (entityType == null) return;
    final handlers = _successHandlers[entityType];
    if (handlers == null || handlers.isEmpty) return;
    for (final handler in handlers) {
      try {
        await handler(row, responseBody);
      } catch (e) {
        print('❌ [SyncQueue] success handler error ($entityType): $e');
      }
    }
  }

  Future<void> _setInProgress(int id) async {
    final db = await _db.database;
    await db.update(
      'pending_operations',
      {
        'status': 'in_progress',
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> _markSuccess(int id, String responseBody) async {
    final db = await _db.database;
    await db.update(
      'pending_operations',
      {
        'status': 'success',
        'server_response': responseBody,
        'last_error': null,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> _markFailedPermanent(int id, String error) async {
    final db = await _db.database;
    await db.update(
      'pending_operations',
      {
        'status': 'failed_permanent',
        'last_error': _truncate(error, 1000),
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [id],
    );
    print('💀 [SyncQueue] #$id permanent fail: $error');
  }

  Future<void> _retryNowWithoutIncrement(int id) async {
    final db = await _db.database;
    final now = DateTime.now().toUtc().toIso8601String();
    await db.update(
      'pending_operations',
      {
        'status': 'pending',
        'next_retry_at': now,
        'updated_at': now,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> _scheduleRetry(
    int id,
    int currentAttempts,
    int maxAttempts,
    String error,
  ) async {
    final db = await _db.database;
    final nextAttempt = currentAttempts + 1;
    if (nextAttempt >= maxAttempts) {
      await _markFailedPermanent(id, 'max attempts: $error');
      return;
    }
    final delaySec = _backoffSeconds[
        nextAttempt.clamp(0, _backoffSeconds.length - 1)];
    final nextRetry = DateTime.now().toUtc().add(Duration(seconds: delaySec));
    await db.update(
      'pending_operations',
      {
        'status': 'pending',
        'attempts': nextAttempt,
        'next_retry_at': nextRetry.toIso8601String(),
        'last_error': _truncate(error, 1000),
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [id],
    );
    print('⏳ [SyncQueue] #$id retry $nextAttempt/$maxAttempts en ${delaySec}s');
  }

  Future<void> _emitCount() async {
    try {
      _pendingCountController.add(await countPending());
    } catch (_) {}
  }

  /// Cantidad de operaciones aún por sincronizar.
  Future<int> countPending() async {
    final db = await _db.database;
    final result = await db.rawQuery(
      "SELECT COUNT(*) AS c FROM pending_operations WHERE status IN ('pending', 'in_progress')",
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }

  /// Operaciones fallidas permanentes (para UI de revisión manual).
  Future<List<Map<String, dynamic>>> getFailedPermanent({int limit = 100}) async {
    final db = await _db.database;
    return db.query(
      'pending_operations',
      where: "status = 'failed_permanent'",
      orderBy: 'updated_at DESC',
      limit: limit,
    );
  }

  /// Reintenta una operación fallida permanente (reset).
  Future<void> retryFailed(int id) async {
    final db = await _db.database;
    final now = DateTime.now().toUtc().toIso8601String();
    await db.update(
      'pending_operations',
      {
        'status': 'pending',
        'attempts': 0,
        'next_retry_at': now,
        'last_error': null,
        'updated_at': now,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
    await _emitCount();
    drain();
  }

  /// Borra operaciones exitosas anteriores a [keepDays] días.
  Future<int> purgeOldSuccessful({int keepDays = 7}) async {
    final db = await _db.database;
    final limit = DateTime.now()
        .toUtc()
        .subtract(Duration(days: keepDays))
        .toIso8601String();
    final deleted = await db.delete(
      'pending_operations',
      where: "status = 'success' AND updated_at < ?",
      whereArgs: [limit],
    );
    if (deleted > 0) {
      print('🧹 [SyncQueue] purgadas $deleted operaciones exitosas');
    }
    return deleted;
  }

  String _truncate(String s, int max) =>
      s.length <= max ? s : s.substring(0, max);

  void dispose() {
    stop();
    _pendingCountController.close();
    _syncingController.close();
  }
}
