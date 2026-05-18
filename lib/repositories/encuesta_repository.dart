import 'dart:convert';
import 'package:http/http.dart' as http;
import '../core/env.dart';
import '../models/encuesta_model.dart';
import '../services/auth_service.dart';
import 'generic_repository.dart';

class EncuestaRepository {
  final GenericRepository _repo = GenericRepository.instance;
  final AuthService _authService = AuthService();

  /// Obtiene las preguntas de una visita
  Future<EncuestaModel?> getEncuesta(String visitaId) async {
    return _repo.getById<EncuestaModel>(
      path: '/salesperson/me/schedules/$visitaId/with-questions',
      fromJson: (json) => EncuestaModel.fromJson(json),
    );
  }

  /// Envía todas las respuestas en un array
  Future<bool> enviarEncuesta({
    required String visitId,
    required List<Map<String, dynamic>> respuestas,
  }) async {
    try {
      final token = await _authService.getToken();
      final url = Uri.parse('${Env.apiBaseUrl}/salesperson/me/answers');

      final body = jsonEncode(respuestas);

      print('📤 Enviando encuesta completa:');
      print('🌐 URL: $url');
      print('📦 Body: $body');

      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
          'Accept': '*/*',
        },
        body: body,
      ).timeout(const Duration(seconds: 30));

      print('📊 Status: ${response.statusCode}');
      print('📝 Response: ${response.body}');

      return response.statusCode == 200 || response.statusCode == 201;
    } catch (e) {
      print('❌ Error enviando encuesta: $e');
      return false;
    }
  }

  /// Construye el array de respuestas y lo envía
  Future<bool> enviarTodasLasRespuestas({
    required String visitId,
    required Map<String, dynamic> respuestas,
    double? lat,
    double? lng,
    String? foto1Path,
    String? foto2Path,
  }) async {
    // Construir notas con ubicación y fotos
    final partes = <String>[];
    if (lat != null && lng != null) {
      partes.add('📍 $lat, $lng');
    }
    if (foto1Path != null) {
      partes.add('📷 Foto 1: $foto1Path');
    }
    if (foto2Path != null) {
      partes.add('📷 Foto 2: $foto2Path');
    }
    final notas = partes.isNotEmpty ? partes.join(' | ') : null;

    // Construir array de respuestas
    final List<Map<String, dynamic>> arrayRespuestas = [];

    respuestas.forEach((preguntaId, valor) {
      if (valor == null || valor.toString().isEmpty) return;

      final respuesta = <String, dynamic>{
        'visit_id': int.tryParse(visitId) ?? 0,           // ← Convertir a int
        'question_id': int.tryParse(preguntaId) ?? 0,     // ← Convertir a int
      };

      // Determinar si es texto o rating/opción
      if (valor is int) {
        respuesta['answer_option'] = valor.toString();
      } else {
        respuesta['answer_text'] = valor.toString();
      }

      // Agregar notas solo a la primera respuesta
      if (notas != null && arrayRespuestas.isEmpty) {
        respuesta['notes'] = notas;
      }

      arrayRespuestas.add(respuesta);
});

    if (arrayRespuestas.isEmpty) {
      print('⚠️ No hay respuestas para enviar');
      return false;
    }

    return enviarEncuesta(visitId: visitId, respuestas: arrayRespuestas);
  }
}