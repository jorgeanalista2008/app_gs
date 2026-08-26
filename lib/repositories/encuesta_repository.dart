import 'package:sqflite/sqflite.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../core/env.dart';
import '../models/encuesta_model.dart';
import '../services/database_helper.dart';
import '../models/pregunta_model.dart';

class EncuestaRepository {
  final DatabaseHelper _db = DatabaseHelper.instance;

  /// Obtiene detalle de visita con respuestas desde la API backend
  Future<Map<String, dynamic>?> fetchVisitaConRespuestasFromApi({
    required String visitId,
    required String email,
    required String password,
  }) async {
    try {
      final url = Uri.parse('${Env.apiBaseUrl}/salesperson/auth/visits/$visitId/with-answers');
      final payload = {
        'email': email,
        'password': password,
      };

      print('📡 Consultando visita con respuestas en API: $url');
      final response = await http.post(
        url,
        headers: {
          'Accept': '*/*',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(payload),
      ).timeout(const Duration(seconds: 20));

      print('📊 Status respuestas API: ${response.statusCode}');

      if (response.statusCode == 200) {
        final Map<String, dynamic> decoded = jsonDecode(response.body);
        return decoded;
      }
      return null;
    } catch (e) {
      print('❌ Error obteniendo visita con respuestas desde API: $e');
      return null;
    }
  }

  /// Obtiene las preguntas de una visita desde SQLite
  Future<EncuestaModel?> getEncuesta(String visitaId) async {
    try {
      final encuestaData = await _db.getEncuestaByVisitaId(visitaId);
      
      if (encuestaData != null && encuestaData['questions_json'] != null) {
        final questionsList = jsonDecode(encuestaData['questions_json'] as String);
        
        return EncuestaModel(
          id: encuestaData['id']?.toString() ?? '',
          salespersonId: encuestaData['salesperson_id']?.toString() ?? '',
          customerId: encuestaData['customer_id']?.toString() ?? '',
          status: 'PENDING',
          questions: (questionsList as List)
              .map((q) => PreguntaModel.fromJson(q as Map<String, dynamic>))
              .toList(),
          answers: [],
        );
      }
      return null;
    } catch (e) {
      print('❌ Error obteniendo encuesta local: $e');
      return null;
    }
  }

  /// Obtiene las preguntas específicas asignadas a una visita (por question_ids)
  /// Respeta el orden del array question_ids
  Future<EncuestaModel?> getEncuestaVisita(String visitaId) async {
    try {
      final db = await _db.database;

      // Obtener visita con sus question_ids
      final visitaResult = await db.query(
        'visitas',
        where: 'id = ?',
        whereArgs: [visitaId],
        limit: 1,
      );

      if (visitaResult.isEmpty) {
        print('⚠️ Visita $visitaId no encontrada');
        return null;
      }

      final visita = visitaResult.first;
      final questionIdsJson = visita['question_ids']?.toString() ?? '[]';
      final packName = visita['pack_name']?.toString() ?? 'Encuesta personalizada';
      final customerId = visita['customer_id']?.toString() ?? '';

      // Parsear question_ids
      List<int> questionIds;
      try {
        final parsed = jsonDecode(questionIdsJson) as List?;
        questionIds = (parsed ?? []).map((e) => int.parse(e.toString())).toList();
      } catch (e) {
        print('⚠️ Error parseando question_ids para visita $visitaId: $e');
        return null;
      }

      // Si no hay preguntas asignadas, retornar modelo vacío
      if (questionIds.isEmpty) {
        return EncuestaModel(
          id: visitaId,
          salespersonId: 'vendedor',
          customerId: customerId,
          status: 'PENDING',
          questions: [],
          answers: [],
          packName: packName,
        );
      }

      // Obtener todas las preguntas del catálogo
      final todasPreguntasData = await db.query('preguntas');

      // Mapear por ID para búsqueda rápida
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

      // Construir lista de preguntas en el orden de question_ids
      final preguntas = <PreguntaModel>[];
      for (final qId in questionIds) {
        final p = preguntasMap[qId];
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
            sortOrder: qId,
            orderIndex: qId,
          ));
        }
      }

      return EncuestaModel(
        id: visitaId,
        salespersonId: 'vendedor',
        customerId: customerId,
        status: 'PENDING',
        questions: preguntas,
        answers: [],
        packName: packName,
      );
    } catch (e) {
      print('❌ Error obteniendo encuesta de visita: $e');
      return null;
    }
  }

  /// Obtiene una encuesta (plantilla) por su ID para aplicarla a una visita
  Future<EncuestaModel?> getPlantillaEncuesta(String plantillaId, String visitaId) async {
    try {
      final db = await _db.database;
      
      // Obtener la plantilla
      final plantillaData = await db.query(
        'encuestas',
        where: 'id = ?',
        whereArgs: [plantillaId],
        limit: 1,
      );
      
      if (plantillaData.isEmpty) return null;
      
      // Obtener las preguntas asociadas
      final preguntasData = await _db.getPreguntasByEncuestaId(plantillaId);
      
      final List<PreguntaModel> questions = preguntasData.map((p) {
        final opcionesStr = p['opciones']?.toString() ?? '';
        final responseOptions = opcionesStr.isNotEmpty
            ? PreguntaOption.parseOptions(opcionesStr)
            : null;
        final effectiveId = p['server_id']?.toString().isNotEmpty == true
            ? p['server_id'].toString()
            : (p['id']?.toString() ?? '');

        return PreguntaModel(
          id: effectiveId,
          code: effectiveId,
          description: p['descripcion']?.toString() ?? '',
          questionType: p['tipo']?.toString() ?? 'TEXT',
          isRequired: p['es_requerida'] == 1,
          responseOptions: responseOptions,
          sortOrder: p['orden'] as int? ?? 0,
          orderIndex: p['orden'] as int? ?? 0,
        );
      }).toList();
      
      // Obtener visita para extraer customer_id
      final visitaResult = await db.query(
        'visitas',
        where: 'id = ?',
        whereArgs: [visitaId],
        limit: 1,
      );
      
      String customerId = '';
      if (visitaResult.isNotEmpty) {
        customerId = visitaResult.first['customer_id']?.toString() ?? '';
      }
      
      return EncuestaModel(
        id: plantillaId,
        salespersonId: 'vendedor',
        customerId: customerId,
        status: 'PENDING',
        questions: questions,
        answers: [],
      );
    } catch (e) {
      print('❌ Error obteniendo plantilla de encuesta: $e');
      return null;
    }
  }

  /// Guarda una encuesta con sus preguntas en SQLite
  Future<bool> guardarEncuesta({
    required String id,
    required String visitId,
    String? salespersonId,
    String? customerId,
    required List<Map<String, dynamic>> questions,
  }) async {
    try {
      await _db.guardarEncuestaPreguntas(
        id: id,
        visitId: visitId,
        salespersonId: salespersonId,
        customerId: customerId,
        questionsJson: jsonEncode(questions),
      );
      print('✅ Encuesta guardada localmente: $id');
      return true;
    } catch (e) {
      print('❌ Error guardando encuesta: $e');
      return false;
    }
  }

  /// Guarda respuestas de una encuesta en SQLite
  Future<bool> guardarRespuestas({
    required String visitId,
    required String customerName,
    required Map<String, dynamic> respuestas,
    double? lat,
    double? lng,
    String? foto1Path,
    String? foto2Path,
  }) async {
    try {
      final arrayRespuestas = <Map<String, dynamic>>[];
      
      // Obtener todas las preguntas de la base de datos para buscar descripción y tipo
      final db = await _db.database;
      final dbPreguntas = await db.query('preguntas');
      final mapaPreguntas = {for (var p in dbPreguntas) p['id'].toString(): p};

      respuestas.forEach((preguntaId, valor) {
        if (valor == null || valor.toString().isEmpty) return;
        
        final preguntaInfo = mapaPreguntas[preguntaId.toString()];
        final descripcion = preguntaInfo?['descripcion']?.toString() ?? '';
        final tipo = preguntaInfo?['tipo']?.toString() ?? '';

        final respuesta = <String, dynamic>{
          'visit_id': visitId,
          'question_id': preguntaId,
          'question_description': descripcion,
          'description': descripcion,
          'question_type': tipo,
        };
        
        if (tipo == 'MULTIPLE_CHOICE') {
          respuesta['answer_option'] = valor.toString();
        } else if (valor is int) {
          respuesta['answer_option'] = valor.toString();
        } else {
          respuesta['answer_text'] = valor.toString();
        }
        
        arrayRespuestas.add(respuesta);
      });

      if (arrayRespuestas.isEmpty) return false;

      final id = await _db.guardarRespuesta(
        visitId: visitId,
        customerName: customerName,
        respuestasJson: jsonEncode(arrayRespuestas),
        lat: lat,
        lng: lng,
        foto1Path: foto1Path,
        foto2Path: foto2Path,
      );

      print('✅ Respuestas guardadas localmente (ID: $id)');
      print('📡 === DETALLE DE RESPUESTAS GUARDADAS (DEBUG) ===');
      try {
        const encoder = JsonEncoder.withIndent('  ');
        final prettyAnswers = encoder.convert(arrayRespuestas);
        print('📦 Respuestas:\n$prettyAnswers');
      } catch (_) {
        print('📦 Respuestas (raw): $arrayRespuestas');
      }
      print('==================================================');
      return id > 0;
    } catch (e) {
      print('❌ Error guardando respuestas: $e');
      return false;
    }
  }

  /// Obtiene respuestas guardadas de una visita
  Future<List<Map<String, dynamic>>> getRespuestas(String visitId) async {
    try {
      final db = await _db.database;
      return await db.query(
        'respuestas_pendientes',
        where: 'visit_id = ?',
        whereArgs: [visitId],
        orderBy: 'fecha_creacion DESC',
      );
    } catch (e) {
      print('❌ Error obteniendo respuestas: $e');
      return [];
    }
  }

  /// Verifica si una visita ya tiene respuestas guardadas
 /// Verifica si una visita ya tiene respuestas guardadas
Future<bool> tieneRespuestas(String visitId) async {
  try {
    final db = await _db.database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as total FROM respuestas_pendientes WHERE visit_id = ?',
      [visitId],
    );
    final total = Sqflite.firstIntValue(result) ?? 0;
    return total > 0;
  } catch (e) {
    return false;
  }
}

  /// Elimina respuestas de una visita
  Future<bool> eliminarRespuestas(String visitId) async {
    try {
      final db = await _db.database;
      await db.delete(
        'respuestas_pendientes',
        where: 'visit_id = ?',
        whereArgs: [visitId],
      );
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Obtiene todas las encuestas guardadas
  Future<List<Map<String, dynamic>>> getTodasLasEncuestas() async {
    try {
      final db = await _db.database;
      return await db.query('encuestas_visita', orderBy: 'fecha_sync DESC');
    } catch (e) {
      return [];
    }
  }

  /// Crea una pregunta localmente (offline) que será enviada al servidor en
  /// la próxima sincronización. Retorna el id local (uuid).
  Future<String> crearPreguntaOffline({
    required String descripcion,
    required String tipo,
    bool esRequerida = false,
    List<String>? opciones,
    int orden = 100,
  }) async {
    final localId = 'v_${DateTime.now().microsecondsSinceEpoch}';
    final opcionesJson = (opciones != null && opciones.isNotEmpty)
        ? jsonEncode(opciones)
        : null;

    await _db.guardarPreguntaTemplate(
      id: localId,
      encuestaId: 'encuesta_general',
      descripcion: descripcion,
      tipo: tipo,
      esRequerida: esRequerida ? 1 : 0,
      opciones: opcionesJson,
      orden: orden,
      serverId: null,
      sincronizado: 0,
    );

    return localId;
  }

  /// Lista todas las preguntas locales (incluye pendientes de push y ya sync)
  Future<List<Map<String, dynamic>>> listarPreguntas() async {
    final db = await _db.database;
    return await db.query(
      'preguntas',
      where: 'encuesta_id = ?',
      whereArgs: ['encuesta_general'],
      orderBy: 'orden ASC, updated_at DESC',
    );
  }

  /// Obtiene estadísticas de encuestas
  Future<Map<String, int>> getEstadisticas() async {
    try {
      final db = await _db.database;
      final totalEncuestas = Sqflite.firstIntValue(
        await db.rawQuery('SELECT COUNT(*) FROM encuestas_visita'),
      ) ?? 0;
      final totalRespuestas = Sqflite.firstIntValue(
        await db.rawQuery('SELECT COUNT(*) FROM respuestas_pendientes'),
      ) ?? 0;
      final pendientes = Sqflite.firstIntValue(
        await db.rawQuery('SELECT COUNT(*) FROM respuestas_pendientes WHERE sincronizado = 0'),
      ) ?? 0;

      return {
        'total_encuestas': totalEncuestas,
        'total_respuestas': totalRespuestas,
        'pendientes': pendientes,
      };
    } catch (e) {
      return {'total_encuestas': 0, 'total_respuestas': 0, 'pendientes': 0};
    }
  }
}