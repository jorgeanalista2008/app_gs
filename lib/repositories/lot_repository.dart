// repositories/lot_repository.dart - VERSIÓN CORREGIDA
import 'dart:convert';
import 'package:app_gs/models/delivery_history_model.dart';

import 'package:http/http.dart' as http;
import '../core/env.dart';

class LotRepository {
  static const String _baseUrl = Env.apiBaseUrl;
  
  // Método para obtener detalles del lote (ya funciona)
  Future<Map<String, dynamic>> getLotDetails({
    required String lotId,
    required String userId,
    double? lat,
    double? lng,
  }) async {
    try {
      print('🔍 LotRepository - Consultando lote: $lotId');
      
      final url = Uri.parse('$_baseUrl/index.php').replace(queryParameters: {
        'action': 'mempaquetado',
        'datos': '7',
        'c': 'VehiculoData',
        't': 'jm_paquetes_reg',
        'user_id': userId,
        'filtro': lotId,
        if (lat != null) 'lat': lat.toString(),
        if (lng != null) 'lng': lng.toString(),
        '_': DateTime.now().millisecondsSinceEpoch.toString(),
      });
      
      final response = await http.get(
        url,
        headers: {'Accept': 'application/json'},
      ).timeout(const Duration(seconds: 30));
      
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        return {
          'success': false,
          'message': 'Error HTTP ${response.statusCode}',
          'error_code': 'HTTP_${response.statusCode}',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Error de conexión: $e',
        'error_code': 'CONNECTION_ERROR',
      };
    }
  }
  
  // MÉTODO CORREGIDO - asegurando que todos los valores sean String
  Future<bool> verifyDelivery({
    required String lotId,
    required String userId,
    required double lat,
    required double lng,
    String observations = '',
    String? paqueteId,
  }) async {
    try {
      print('✅ LotRepository - Confirmando entrega:');
      print('  📦 Lote ID: $lotId');
      print('  👤 Usuario ID: $userId');
      print('  📍 Ubicación: $lat, $lng');
      
      // URL del endpoint según tu PHP: datos=3
      final url = Uri.parse('$_baseUrl/index.php').replace(queryParameters: {
        'action': 'despacho',
        'tipo' : '1',
        'accion': '1',
        'datos': '5',
        'c': 'VehiculoData',
      });
      
      print('🌐 URL: ${url.toString()}');
      
      // IMPORTANTE: Asegurar que TODOS los valores sean String
      final Map<String, String> body = {
        'loteId': lotId, // String
        'notas': observations.isNotEmpty 
            ? observations 
            : 'Entregado por app móvil - Usuario: $userId',
        'confirmado': '1', // IMPORTANTE: String "1" no int 1
        'userId': userId, // String
        'lat': lat.toString(), // Convertir double a String
        'lng': lng.toString(), // Convertir double a String
        'fecha': DateTime.now().toIso8601String(), // String
      };
      
      // Agregar paqueteId solo si existe y no es vacío
      if (paqueteId != null && paqueteId.isNotEmpty && paqueteId != '0') {
        body['paqueteId'] = paqueteId;
      }
      
      print('📦 Body a enviar:');
      body.forEach((key, value) {
        print('   $key: $value (${value.runtimeType})');
      });
      
      // IMPORTANTE: Usar application/x-www-form-urlencoded como especifica PHP
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/x-www-form-urlencoded',
          'Accept': 'application/json',
        },
        body: body, // http package convierte Map<String, String> correctamente
      ).timeout(const Duration(seconds: 30));
      
      print('📊 Status Code: ${response.statusCode}');
      print('📝 Response: ${response.body}');
      
      if (response.statusCode == 200) {
        try {
          final jsonResponse = jsonDecode(response.body);
          
          if (jsonResponse is Map<String, dynamic>) {
            if (jsonResponse.containsKey('success')) {
              return jsonResponse['success'] == true;
            }
          }
          
          return false;
          
        } catch (e) {
          print('❌ Error parseando respuesta: $e');
          return false;
        }
      } else {
        print('❌ Error HTTP: ${response.statusCode}');
        return false;
      }
    } catch (e) {
      print('❌ Error en verifyDelivery: $e');
      
      // Debug más detallado del error
      if (e is TypeError) {
        print('💥 TypeError details:');
      
        print('  Stack: ${e.stackTrace}');
      }
      
      return false;
    }
  }
  
  // Método alternativo MÁS SEGURO usando Uri.encodeComponent
  Future<bool> verifyDeliveryAlt({
    required String lotId,
    required String userId,
    required double lat,
    required double lng,
    String observations = '',
    String? paqueteId,
  }) async {
    try {
      final url = Uri.parse('$_baseUrl/index.php').replace(queryParameters: {
        'action': 'despacho',
        'tipo' : '1',
        'accion': '1',
        'datos': '5',
        'c': 'VehiculoData',
      });
      
      // Construir string manualmente para evitar problemas de tipo
      final bodyString = 'loteId=${Uri.encodeComponent(lotId)}'
          '&notas=${Uri.encodeComponent(observations.isNotEmpty ? observations : 'Entregado por app móvil')}'
          '&confirmado=1'
          '&userId=${Uri.encodeComponent(userId)}'
          '&lat=${Uri.encodeComponent(lat.toString())}'
          '&lng=${Uri.encodeComponent(lng.toString())}'
          '&fecha=${Uri.encodeComponent(DateTime.now().toIso8601String())}'
          '${paqueteId != null && paqueteId.isNotEmpty && paqueteId != '0' ? '&paqueteId=${Uri.encodeComponent(paqueteId)}' : ''}';
      
      print('🌐 URL: ${url.toString()}');
      print('📦 Body string: $bodyString');
      
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/x-www-form-urlencoded',
          'Accept': 'application/json',
        },
        body: bodyString,
      ).timeout(const Duration(seconds: 30));
      
      print('📊 Status: ${response.statusCode}');
      
      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(response.body);
        return jsonResponse['success'] == true;
      }
      
      return false;
    } catch (e) {
      print('❌ Error en verifyDeliveryAlt: $e');
      return false;
    }
  }

  // En repositories/lot_repository.dart
Future<List<DeliveryHistory>> getDeliveryHistory({
  required String userId,
  DateTime? startDate,
  DateTime? endDate,
  int limit = 50,
  int offset = 0,
}) async {
  try {
    print('📚 Obteniendo historial de entregas para usuario: $userId');
    
    final url = Uri.parse('$_baseUrl/index.php').replace(queryParameters: {
      'action': 'empaquetado',
      'tipo': '1',
      'accion': '2',
      'datos': '9', // Nuevo endpoint para historial
      'c': 'VehiculoData',
      't': 'historial',
      'user_id': userId,
      'limit': limit.toString(),
      'offset': offset.toString(),
      if (startDate != null) 'fecha_inicio': startDate.toIso8601String(),
      if (endDate != null) 'fecha_fin': endDate.toIso8601String(),
      '_': DateTime.now().millisecondsSinceEpoch.toString(),
    });
    
    print('🌐 URL historial: ${url.toString()}');
    
    final response = await http.get(
      url,
      headers: {'Accept': 'application/json'},
    ).timeout(const Duration(seconds: 30));
    
    print('📊 Status historial: ${response.statusCode}');
    
    if (response.statusCode == 200) {
      final jsonResponse = jsonDecode(response.body);
      
      if (jsonResponse['success'] == true) {
        final List<dynamic> data = jsonResponse['data'] ?? [];
        final List<DeliveryHistory> historial = [];
        
        for (var item in data) {
          try {
            historial.add(DeliveryHistory.fromJson(item));
          } catch (e) {
            print('❌ Error parseando item del historial: $e');
          }
        }
        
        print('✅ Historial obtenido: ${historial.length} entregas');
        return historial;
      } else {
        print('❌ Error en respuesta del historial: ${jsonResponse['message']}');
        return [];
      }
    }
    
    return [];
  } catch (e) {
    print('❌ Error en getDeliveryHistory: $e');
    return [];
  }
}

// Método alternativo si no tienes endpoint específico (usa la misma consulta que para lotes)
Future<List<DeliveryHistory>> getDeliveryHistoryFromPackages({
  required String userId,
}) async {
  try {
    print('📦 Obteniendo historial desde paquetes entregados...');
    
    // Usar el mismo endpoint pero filtrando por estatus=2 (entregado)
    final url = Uri.parse('$_baseUrl/index.php').replace(queryParameters: {
      'action': 'empaquetado',
      'tipo': '1',
      'accion': '2',
      'datos': '9', // Nuevo endpoint para historial
      'c': 'VehiculoData',
      't': 'jm_paquetes_reg',
      'user_id': userId,
      'estatus': '2', // Solo entregados
      'limit': '100',
      '_': DateTime.now().millisecondsSinceEpoch.toString(),
    });
    
    final response = await http.get(
      url,
      headers: {'Accept': 'application/json'},
    ).timeout(const Duration(seconds: 30));
    
    if (response.statusCode == 200) {
      final jsonResponse = jsonDecode(response.body);
      
      if (jsonResponse['success'] == true) {
        final data = jsonResponse['data'];
        final List<DeliveryHistory> historial = [];
        
        if (data is Map && data.containsKey('paquetes')) {
          final paquetes = data['paquetes'] as List;
          
          for (var paquete in paquetes) {
            try {
              final entrega = DeliveryHistory(
                id: paquete['id']?.toString() ?? '0',
                loteId: paquete['co_lote']?.toString() ?? '',
                paqueteId: paquete['id']?.toString() ?? '0',
                cliente: paquete['cli_des']?.toString().trim() ?? 'Cliente no especificado',
                producto: 'Paquete ${paquete['numero_paquete']?.toString() ?? '1'}',
                cantidad: paquete['numero_paquete'] != null 
                    ? int.tryParse(paquete['numero_paquete'].toString()) ?? 1 
                    : 1,
                estado: 'Entregado',
                fechaEntrega: paquete['dato_extra1'] != null 
                    ? DateTime.parse(paquete['dato_extra1'].toString())
                    : DateTime.now(),
                observaciones: paquete['facturas_texto']?.toString() ?? '',
                userId: userId,
                facturas: paquete['facturas_texto']?.toString(),
                codigoCliente: paquete['co_cli']?.toString(),
                codigoVendedor: paquete['co_ven']?.toString(),
                cantidadPaquetes: paquete['cantidad_paquetes'] != null 
                    ? int.tryParse(paquete['cantidad_paquetes'].toString()) ?? 1 
                    : 1,
              );
              
              historial.add(entrega);
            } catch (e) {
              print('❌ Error creando DeliveryHistory: $e');
            }
          }
        }
        
        print('✅ Historial obtenido desde paquetes: ${historial.length} entregas');
        return historial;
      }
    }
    
    return [];
  } catch (e) {
    print('❌ Error en getDeliveryHistoryFromPackages: $e');
    return [];
  }
}
}