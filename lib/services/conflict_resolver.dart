import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import 'database_helper.dart';

enum ConflictAction { applyServer, keepLocal, noChange }

class ConflictResult {
  final ConflictAction action;
  final DateTime? serverUpdatedAt;
  const ConflictResult({required this.action, this.serverUpdatedAt});
}

/// Resuelve conflictos local vs servidor con estrategia last-write-wins.
///
/// Reglas:
/// 1. Si no hay row local → insertar (`applyServer`).
/// 2. Si local `sincronizado=1` (sin cambios pendientes) → tomar servidor cuando
///    `server_updated_at` es más nuevo o desconocido. Caso contrario, sin cambio.
/// 3. Si local `sincronizado=0` (cambios pendientes) → comparar
///    `local.updated_at` vs `server.updated_at`:
///    - Local más nuevo → `keepLocal`, log conflicto `local_wins`.
///    - Server más nuevo o empate → `applyServer`, log conflicto `server_wins`.
///
/// Cuando el servidor no devuelve `updated_at` (GET list sin timestamp), trata
/// `serverUpdatedAt` como `null` y siempre aplica el servidor si local está
/// sincronizado, o conserva local si hay cambios pendientes.
class ConflictResolver {
  static final ConflictResolver instance = ConflictResolver._();
  ConflictResolver._();

  final DatabaseHelper _db = DatabaseHelper.instance;

  Future<ConflictResult> resolve({
    required String entityType,
    required String entityId,
    Map<String, dynamic>? localRow,
    required Map<String, dynamic> serverRow,
    String serverUpdatedAtKey = 'updated_at',
  }) async {
    final serverUpdatedAt = _parseDate(serverRow[serverUpdatedAtKey]);

    if (localRow == null) {
      return ConflictResult(
        action: ConflictAction.applyServer,
        serverUpdatedAt: serverUpdatedAt,
      );
    }

    final localSynced = (localRow['sincronizado'] as int?) ?? 1;
    final localUpdatedAt = _parseDate(localRow['updated_at']);
    final localServerUpdatedAt = _parseDate(localRow['server_updated_at']);

    // Local sin cambios pendientes → confiamos en servidor.
    if (localSynced == 1) {
      if (serverUpdatedAt == null) {
        return ConflictResult(
          action: ConflictAction.applyServer,
          serverUpdatedAt: serverUpdatedAt,
        );
      }
      if (localServerUpdatedAt == null ||
          serverUpdatedAt.isAfter(localServerUpdatedAt)) {
        return ConflictResult(
          action: ConflictAction.applyServer,
          serverUpdatedAt: serverUpdatedAt,
        );
      }
      return const ConflictResult(action: ConflictAction.noChange);
    }

    // Local con cambios pendientes → posible conflicto.
    if (serverUpdatedAt == null) {
      // Sin timestamp servidor, no podemos comparar — preservamos local.
      return const ConflictResult(action: ConflictAction.keepLocal);
    }

    if (localUpdatedAt != null && localUpdatedAt.isAfter(serverUpdatedAt)) {
      await _logConflict(
        entityType: entityType,
        entityId: entityId,
        localUpdatedAt: localUpdatedAt,
        serverUpdatedAt: serverUpdatedAt,
        resolution: 'local_wins',
        localSnapshot: localRow,
        serverSnapshot: serverRow,
      );
      return const ConflictResult(action: ConflictAction.keepLocal);
    }

    await _logConflict(
      entityType: entityType,
      entityId: entityId,
      localUpdatedAt: localUpdatedAt,
      serverUpdatedAt: serverUpdatedAt,
      resolution: 'server_wins',
      localSnapshot: localRow,
      serverSnapshot: serverRow,
    );
    return ConflictResult(
      action: ConflictAction.applyServer,
      serverUpdatedAt: serverUpdatedAt,
    );
  }

  Future<void> _logConflict({
    required String entityType,
    required String entityId,
    required DateTime? localUpdatedAt,
    required DateTime? serverUpdatedAt,
    required String resolution,
    required Map<String, dynamic> localSnapshot,
    required Map<String, dynamic> serverSnapshot,
  }) async {
    try {
      final db = await _db.database;
      await db.insert('sync_conflicts', {
        'entity_type': entityType,
        'entity_id': entityId,
        'local_updated_at': localUpdatedAt?.toIso8601String(),
        'server_updated_at': serverUpdatedAt?.toIso8601String(),
        'resolution': resolution,
        'local_snapshot': jsonEncode(localSnapshot),
        'server_snapshot': jsonEncode(serverSnapshot),
        'resolved_at': DateTime.now().toUtc().toIso8601String(),
        'reviewed': 0,
      });
      print('⚠️ [Conflict] $entityType/$entityId → $resolution');
    } catch (e) {
      print('❌ [Conflict] error logueando: $e');
    }
  }

  /// Lista conflictos para revisión manual en UI admin.
  Future<List<Map<String, dynamic>>> getConflicts({
    bool? reviewed,
    String? entityType,
    int limit = 200,
  }) async {
    final db = await _db.database;
    final whereParts = <String>[];
    final args = <dynamic>[];
    if (reviewed != null) {
      whereParts.add('reviewed = ?');
      args.add(reviewed ? 1 : 0);
    }
    if (entityType != null) {
      whereParts.add('entity_type = ?');
      args.add(entityType);
    }
    return db.query(
      'sync_conflicts',
      where: whereParts.isEmpty ? null : whereParts.join(' AND '),
      whereArgs: whereParts.isEmpty ? null : args,
      orderBy: 'resolved_at DESC',
      limit: limit,
    );
  }

  Future<int> countUnreviewed() async {
    final db = await _db.database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) AS c FROM sync_conflicts WHERE reviewed = 0',
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }

  Future<void> markReviewed(int id) async {
    final db = await _db.database;
    await db.update(
      'sync_conflicts',
      {'reviewed': 1},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Fuerza aplicar la versión local sobre la servidor: re-encola el registro
  /// como pendiente de push. Lo dejamos para Fase 3 (UI). Aquí solo
  /// reseteamos `sincronizado` para que próximo push lo tome.
  Future<void> forceLocalWins({
    required String table,
    required String idColumn,
    required dynamic id,
  }) async {
    final db = await _db.database;
    await db.update(
      table,
      {
        'sincronizado': 0,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      },
      where: '$idColumn = ?',
      whereArgs: [id],
    );
  }

  /// Purga conflictos resueltos antiguos.
  Future<int> purgeOld({int keepDays = 30}) async {
    final db = await _db.database;
    final limit = DateTime.now()
        .toUtc()
        .subtract(Duration(days: keepDays))
        .toIso8601String();
    return db.delete(
      'sync_conflicts',
      where: 'reviewed = 1 AND resolved_at < ?',
      whereArgs: [limit],
    );
  }

  DateTime? _parseDate(dynamic v) {
    if (v == null) return null;
    if (v is DateTime) return v.toUtc();
    final s = v.toString();
    if (s.isEmpty) return null;
    try {
      return DateTime.parse(s).toUtc();
    } catch (_) {
      return null;
    }
  }
}
