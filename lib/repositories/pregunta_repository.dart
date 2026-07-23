import 'dart:convert';
import '../services/database_helper.dart';
import '../services/sync_queue_service.dart';

class PreguntaRepository {
  final DatabaseHelper _db = DatabaseHelper.instance;
  static const String entityType = 'visit_question';

  /// Registra handler en cola para mapear server_id tras éxito.
  /// Llamar UNA VEZ en main.dart al arrancar.
  static void registerSyncHandlers() {
    SyncQueueService.instance.registerSuccessHandler(
      entityType,
      _onPreguntaPushSuccess,
    );
  }

  static Future<void> _onPreguntaPushSuccess(
    Map<String, dynamic> operation,
    String responseBody,
  ) async {
    final localId = operation['entity_local_id']?.toString();
    if (localId == null) return;
    try {
      // DELETE exitoso: no hay id de servidor que mapear, la fila local
      // ya fue borrada al encolar la operación.
      if (operation['operation'] == 'delete') return;

      final decoded = jsonDecode(responseBody);
      String? serverId;
      if (decoded is Map<String, dynamic>) {
        final data = decoded['data'] is Map<String, dynamic>
            ? decoded['data'] as Map<String, dynamic>
            : decoded;
        serverId = data['id']?.toString();
      }
      if (serverId == null) {
        print('⚠️ [Pregunta] respuesta sin id servidor para $localId');
        return;
      }
      await DatabaseHelper.instance.marcarPreguntaSincronizada(localId, serverId);
      await DatabaseHelper.instance.registrarIdMapping(
        entityType: entityType,
        localId: localId,
        serverId: serverId,
      );
      print('🔗 [Pregunta] mapeada $localId → $serverId');
    } catch (e) {
      print('❌ [Pregunta] error procesando éxito push: $e');
    }
  }

  /// Crea una pregunta offline: insert local + enqueue POST /visit/questions.
  Future<void> crearPregunta({
    required String encuestaId,
    required String descripcion,
    required String tipo,
    bool esRequerida = false,
    String? opciones,
    int orden = 0,
  }) async {
    final localId = 'preg_${DateTime.now().microsecondsSinceEpoch}';

    await _db.guardarPreguntaTemplate(
      id: localId,
      encuestaId: encuestaId,
      descripcion: descripcion,
      tipo: tipo,
      esRequerida: esRequerida ? 1 : 0,
      opciones: opciones,
      orden: orden,
      sincronizado: 0,
    );

    final payload = <String, dynamic>{
      'code': localId,
      'description': descripcion,
      'question_type': tipo,
      'is_required': esRequerida,
      'sort_order': orden,
      if (tipo == 'MULTIPLE_CHOICE' && opciones != null && opciones.isNotEmpty)
        'response_options': opciones,
    };

    await SyncQueueService.instance.enqueue(
      entityType: entityType,
      entityLocalId: localId,
      operation: 'create',
      httpMethod: 'POST',
      endpoint: '/visit/questions',
      payload: payload,
    );

    print('🆕 [Pregunta] creada offline: $localId');
  }

  /// Elimina una pregunta: si aún no fue sincronizada, cancela el push
  /// pendiente y borra localmente. Si ya tiene server_id, encola el DELETE.
  Future<void> eliminarPregunta(String id) async {
    final db = await _db.database;
    final rows = await db.query('preguntas', where: 'id = ?', whereArgs: [id], limit: 1);
    final serverId = rows.isNotEmpty ? rows.first['server_id']?.toString() : null;

    if (serverId == null || serverId.isEmpty) {
      // Nunca llegó a sincronizarse: cancelar el POST pendiente si existe.
      await db.delete(
        'pending_operations',
        where: "entity_type = ? AND entity_local_id = ? AND status = 'pending'",
        whereArgs: [entityType, id],
      );
      await _db.eliminarPreguntaTemplate(id);
      print('🗑️ [Pregunta] eliminada localmente (nunca sincronizada): $id');
      return;
    }

    await _db.eliminarPreguntaTemplate(id);
    await SyncQueueService.instance.enqueue(
      entityType: entityType,
      entityLocalId: id,
      operation: 'delete',
      httpMethod: 'DELETE',
      endpoint: '/visit/questions/$serverId',
    );
    print('🗑️ [Pregunta] eliminada localmente, DELETE encolado para server_id $serverId');
  }
}
