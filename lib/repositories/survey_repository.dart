import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import '../models/survey_pack_model.dart';
import '../models/survey_question_model.dart';
import '../models/survey_assignment_model.dart';
import '../models/customer_360_model.dart';
import '../services/database_helper.dart';
import '../services/auth_service.dart';
import '../services/sync_queue_service.dart';
import 'generic_repository.dart';

class SurveyRepository {
  static final SurveyRepository instance = SurveyRepository._();
  SurveyRepository._();

  final DatabaseHelper _db = DatabaseHelper.instance;
  final GenericRepository _genericRepo = GenericRepository.instance;
  final AuthService _authService = AuthService.instance;

  /// 📍 MÉTODO CLAVE: Obtiene ficha 360 + pack recomendado desde el servidor
  /// Endpoint: POST /survey/auth/customers/:customerId/360
  /// Autenticación: email + password (NO JWT)
  Future<Customer360?> getCustomer360({
    required String customerId,
  }) async {
    try {
      final userId = _authService.userId;
      if (userId == null) {
        print('❌ [SurveyRepository] No hay usuario logueado');
        return null;
      }

      final userLocal = await _db.getUsuario(userId);
      if (userLocal == null) {
        print('❌ [SurveyRepository] No se encontró usuario local');
        return null;
      }

      final username = userLocal['username']?.toString();
      final password = userLocal['password']?.toString();

      if (username == null || password == null) {
        print('❌ [SurveyRepository] Credenciales incompletas');
        return null;
      }

      print('📡 [SurveyRepository] Solicitando ficha 360 para $customerId...');

      // Llamar al endpoint
      final response = await _genericRepo.postOnline<Map<String, dynamic>>(
        path: '/survey/auth/customers/$customerId/360',
        body: {
          'email': username,
          'password': password,
        },
        fromJson: (json) => json,
      );

      if (response == null) {
        print('❌ [SurveyRepository] Respuesta nula del servidor');
        return null;
      }

      final customer360 = Customer360.fromJson(response);

      // Guardar en caché
      await cacheSurveyPack(customer360.recommendedSurvey);
      await _cacheCustomer(customer360.customer, customerId);

      print('✅ [SurveyRepository] Ficha 360 obtenida: ${customer360.customer['name']}');
      return customer360;
    } catch (e) {
      print('❌ [SurveyRepository] Error obteniendo ficha 360: $e');
      return null;
    }
  }

  /// Guarda un pack de encuesta en SQLite local
  Future<void> cacheSurveyPack(SurveyPack? pack) async {
    if (pack == null) return;

    try {
      final db = await _db.database;
      await db.insert(
        'cached_survey_packs',
        {
          'id': pack.id,
          'name': pack.name,
          'pack_type': pack.packType,
          'description': pack.description,
          'questions': jsonEncode(pack.questions.map((q) => q.toJson()).toList()),
          'cached_at': DateTime.now().toUtc().toIso8601String(),
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      print('💾 [SurveyRepository] Pack ${pack.id} cacheado');
    } catch (e) {
      print('❌ [SurveyRepository] Error cacheando pack: $e');
    }
  }

  /// Guarda respuesta pendiente de sincronización
  Future<void> savePendingAnswer({
    required String customerId,
    required String packId,
    required Map<String, dynamic> answers,
  }) async {
    try {
      final db = await _db.database;
      await db.insert(
        'pending_survey_answers',
        {
          'customer_id': customerId,
          'pack_id': packId,
          'answers': jsonEncode(answers),
          'status': 'PENDING',
          'created_at': DateTime.now().toUtc().toIso8601String(),
          'sync_attempts': 0,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      print('📝 [SurveyRepository] Respuesta guardada: $customerId / $packId');

      // Encolar para sincronización
      await SyncQueueService.instance.enqueue(
        entityType: 'survey_answer',
        entityLocalId: '$customerId-$packId',
        operation: 'create',
        httpMethod: 'POST',
        endpoint: '/salesperson/auth/answers',
        payload: answers,
      );
    } catch (e) {
      print('❌ [SurveyRepository] Error guardando respuesta: $e');
    }
  }

  /// Marca asignación como completada en el servidor
  Future<bool> completeAssignment(int assignmentId) async {
    try {
      final userId = _authService.userId;
      if (userId == null) return false;

      final userLocal = await _db.getUsuario(userId);
      if (userLocal == null) return false;

      final username = userLocal['username']?.toString();
      final password = userLocal['password']?.toString();

      if (username == null || password == null) return false;

      print('📤 [SurveyRepository] Marcando asignación $assignmentId como completada...');

      final result = await _genericRepo.postOnline<Map<String, dynamic>>(
        path: '/survey/auth/assignments/$assignmentId/complete',
        body: {
          'email': username,
          'password': password,
        },
        fromJson: (json) => json,
      );

      if (result == null) return false;

      // Actualizar estado local
      final db = await _db.database;
      await db.update(
        'survey_assignments',
        {
          'status': 'COMPLETED',
          'completed_at': DateTime.now().toUtc().toIso8601String(),
        },
        where: 'id = ?',
        whereArgs: [assignmentId],
      );

      // Marcar respuestas como sincronizadas
      await db.update(
        'pending_survey_answers',
        {
          'status': 'SYNCED',
          'synced_at': DateTime.now().toUtc().toIso8601String(),
        },
        where: 'assignment_id = ?',
        whereArgs: [assignmentId],
      );

      print('✅ [SurveyRepository] Asignación $assignmentId completada');
      return true;
    } catch (e) {
      print('❌ [SurveyRepository] Error completando asignación: $e');
      return false;
    }
  }

  /// Obtiene respuestas pendientes para sincronización (retry)
  Future<List<Map<String, dynamic>>> getPendingAnswers() async {
    try {
      final db = await _db.database;
      return await db.query(
        'pending_survey_answers',
        where: 'status = ? OR status = ?',
        whereArgs: ['PENDING', 'FAILED'],
        orderBy: 'created_at ASC',
      );
    } catch (e) {
      print('❌ [SurveyRepository] Error obteniendo respuestas pendientes: $e');
      return [];
    }
  }

  /// Obtiene packs en caché
  Future<List<SurveyPack>> getCachedPacks({String? packType}) async {
    try {
      final db = await _db.database;
      final where = packType != null ? 'pack_type = ?' : null;
      final whereArgs = packType != null ? [packType] : null;

      final rows = await db.query(
        'cached_survey_packs',
        where: where,
        whereArgs: whereArgs,
      );

      return rows.map((row) {
        final questionsJson = row['questions']?.toString() ?? '[]';
        final questionsList = jsonDecode(questionsJson) as List;

        return SurveyPack(
          id: row['id']?.toString() ?? '',
          name: row['name']?.toString() ?? '',
          packType: row['pack_type']?.toString() ?? 'CUSTOM',
          description: row['description']?.toString(),
          questions: questionsList.isEmpty
              ? []
              : (questionsList
                  .map((q) => SurveyQuestion.fromJson(q as Map<String, dynamic>))
                  .toList()),
          isActive: true,
          createdAt: row['cached_at'] != null
              ? DateTime.parse(row['cached_at'].toString())
              : null,
        );
      }).toList();
    } catch (e) {
      print('❌ [SurveyRepository] Error obteniendo packs cacheados: $e');
      return [];
    }
  }

  /// Limpia caché de packs viejos (>30 días)
  Future<void> purgeCachedPacks() async {
    try {
      final db = await _db.database;
      final thirtyDaysAgo =
          DateTime.now().toUtc().subtract(Duration(days: 30)).toIso8601String();

      final deleted = await db.delete(
        'cached_survey_packs',
        where: 'cached_at < ?',
        whereArgs: [thirtyDaysAgo],
      );

      if (deleted > 0) {
        print('🗑️  [SurveyRepository] Limpiados $deleted packs cacheados');
      }
    } catch (e) {
      print('⚠️  [SurveyRepository] Error limpiando caché: $e');
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Métodos privados
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> _cacheCustomer(
    Map<String, dynamic> customerData,
    String customerId,
  ) async {
    try {
      final db = await _db.database;
      await db.insert(
        'cached_customers',
        {
          'id': customerId,
          'name': customerData['name'],
          'code_client_profit': customerData['code_client_profit'],
          'phone': customerData['phone'] ?? customerData['contact']?['phone'],
          'email': customerData['email'] ?? customerData['contact']?['email'],
          'address': customerData['address'] ?? customerData['contact']?['address'],
          'latitude': _parseDouble(customerData['latitude']),
          'longitude': _parseDouble(customerData['longitude']),
          'created_at': customerData['created_at'],
          'last_sync_at': DateTime.now().toUtc().toIso8601String(),
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } catch (e) {
      print('⚠️  [SurveyRepository] Error cacheando cliente: $e');
    }
  }

  static double _parseDouble(dynamic value) {
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0;
    return 0;
  }
}
