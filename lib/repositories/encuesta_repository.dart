import 'package:sqflite/sqflite.dart';
import 'dart:convert';
import '../models/encuesta_model.dart';
import '../services/database_helper.dart';
import '../models/pregunta_model.dart';

class EncuestaRepository {
  final DatabaseHelper _db = DatabaseHelper.instance;

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
      
      respuestas.forEach((preguntaId, valor) {
        if (valor == null || valor.toString().isEmpty) return;
        
        final respuesta = <String, dynamic>{
          'visit_id': visitId,
          'question_id': preguntaId,
        };
        
        if (valor is int) {
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