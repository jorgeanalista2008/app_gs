import 'dart:convert';
import '../services/database_helper.dart';
import '../models/pregunta_model.dart';

class SurveyPackModel {
  final String id;
  final String name;
  final String packType;
  final String? description;
  final bool isActive;
  final List<int> questionIds;

  SurveyPackModel({
    required this.id,
    required this.name,
    required this.packType,
    this.description,
    this.isActive = true,
    this.questionIds = const [],
  });

  factory SurveyPackModel.fromJson(Map<String, dynamic> json) {
    return SurveyPackModel(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      packType: json['pack_type']?.toString() ?? '',
      description: json['description']?.toString(),
      isActive: json['is_active'] == 1 || json['is_active'] == true,
      questionIds: [],
    );
  }
}

class SurveyPackRepository {
  final DatabaseHelper _db = DatabaseHelper.instance;

  /// Obtiene todos los packs disponibles
  Future<List<SurveyPackModel>> getAvailablePacks() async {
    try {
      final db = await _db.database;
      final packData = await db.query(
        'survey_packs',
        where: 'is_active = 1',
        orderBy: 'name ASC',
      );

      if (packData.isEmpty) {
        print('⚠️ No hay packs disponibles');
        return [];
      }

      final packs = <SurveyPackModel>[];
      for (final pack in packData) {
        final packId = pack['id']?.toString() ?? '';

        // Obtener question_ids del pack
        final packQuestionsData = await db.query(
          'survey_pack_questions',
          where: 'pack_id = ?',
          whereArgs: [packId],
          orderBy: 'sort_order ASC',
        );

        final questionIds = packQuestionsData
            .map((pq) => int.tryParse(pq['question_id'].toString()) ?? 0)
            .where((id) => id > 0)
            .toList();

        packs.add(SurveyPackModel(
          id: packId,
          name: pack['name']?.toString() ?? '',
          packType: pack['pack_type']?.toString() ?? '',
          description: pack['description']?.toString(),
          isActive: pack['is_active'] == 1,
          questionIds: questionIds,
        ));
      }

      print('✅ ${packs.length} packs disponibles');
      return packs;
    } catch (e) {
      print('❌ Error obteniendo packs disponibles: $e');
      return [];
    }
  }

  /// Obtiene las preguntas de un pack específico
  Future<List<PreguntaModel>> getPackQuestions(String packId) async {
    try {
      final db = await _db.database;

      // Obtener los question_ids del pack en orden
      final packQuestionsData = await db.query(
        'survey_pack_questions',
        where: 'pack_id = ?',
        whereArgs: [packId],
        orderBy: 'sort_order ASC',
      );

      if (packQuestionsData.isEmpty) {
        print('⚠️ El pack $packId no tiene preguntas');
        return [];
      }

      // Obtener todas las preguntas locales
      final todasPreguntasData = await db.query('preguntas');
      final preguntasMap = <int, Map<String, dynamic>>{};

      for (final p in todasPreguntasData) {
        final id = p['id'];
        if (id != null) {
          final idInt = int.tryParse(id.toString());
          if (idInt != null) {
            preguntasMap[idInt] = p;
          }
        }
      }

      // Construir lista de preguntas en orden
      final preguntas = <PreguntaModel>[];
      for (int i = 0; i < packQuestionsData.length; i++) {
        final packQuestion = packQuestionsData[i];
        final questionId = int.tryParse(packQuestion['question_id'].toString()) ?? 0;

        final p = preguntasMap[questionId];
        if (p != null) {
          final opcionesStr = p['opciones']?.toString() ?? '';
          final responseOptions = opcionesStr.isNotEmpty
              ? PreguntaOption.parseOptions(opcionesStr)
              : null;
          final effectiveId = p['server_id']?.toString().isNotEmpty == true
              ? p['server_id'].toString()
              : (p['id']?.toString() ?? '');

          preguntas.add(PreguntaModel(
            id: effectiveId,
            code: effectiveId,
            description: p['descripcion']?.toString() ?? '',
            questionType: p['tipo']?.toString() ?? 'TEXT',
            isRequired: p['es_requerida'] == 1,
            responseOptions: responseOptions,
            sortOrder: i,
            orderIndex: i,
          ));
        }
      }

      return preguntas;
    } catch (e) {
      print('❌ Error obteniendo preguntas del pack: $e');
      return [];
    }
  }

  /// Asigna un pack a una visita
  Future<bool> assignPackToVisit({
    required String visitId,
    required String packId,
    required String packName,
  }) async {
    try {
      final db = await _db.database;

      // Obtener las preguntas del pack
      final questions = await getPackQuestions(packId);
      final questionIds = questions.map((q) => int.tryParse(q.id) ?? 0).toList();

      // Actualizar la visita con pack_id, pack_name, question_ids
      await db.update(
        'visitas',
        {
          'pack_id': packId,
          'pack_name': packName,
          'pack_type': 'SELECTED',
          'question_ids': jsonEncode(questionIds),
        },
        where: 'id = ?',
        whereArgs: [visitId],
      );

      print('✅ Pack $packId asignado a visita $visitId');
      return true;
    } catch (e) {
      print('❌ Error asignando pack a visita: $e');
      return false;
    }
  }
}
