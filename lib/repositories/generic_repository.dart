import 'dart:convert';
import 'package:http/http.dart' as http;
import '../core/env.dart';
import '../services/auth_service.dart';

class GenericRepository {
  final AuthService _authService = AuthService();

  GenericRepository._();
  static final GenericRepository instance = GenericRepository._();

  /// Obtiene headers con autenticación
  Future<Map<String, String>> _getHeaders() async {
    final token = await _authService.getToken();

    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  /// GET - Obtener lista con soporte para nestedKey
  Future<List<T>> getList<T>({
    required String path,
    Map<String, String>? queryParams,
    String? nestedKey,
    required T Function(Map<String, dynamic> json) fromJson,
  }) async {
    try {
      final uri = Uri.parse('${Env.apiBaseUrl}$path');
      final url = queryParams != null
          ? uri.replace(queryParameters: queryParams)
          : uri;

      final headers = await _getHeaders();

      print('📋 GET List');
      print('🌐 URL: $url');
      print('📂 NestedKey: ${nestedKey ?? "N/A (usando data por defecto)"}');

      final response = await http.get(
        url,
        headers: headers,
      ).timeout(const Duration(seconds: 30));

      print('📊 Status: ${response.statusCode}');

      if (response.statusCode == 200) {
        return _parseResponse<T>(
          response.body,
          fromJson,
          nestedKey: nestedKey,
        );
      }

      if (response.statusCode == 401) {
        await _authService.logout();
        throw Exception('Sesión expirada.');
      }

      print('❌ Error HTTP: ${response.statusCode}');
      return [];
    } catch (e) {
      print('❌ Error en getList: $e');
      rethrow;
    }
  }

  /// GET - Obtener por ID
  Future<T?> getById<T>({
    required String path,
    required T Function(Map<String, dynamic> json) fromJson,
  }) async {
    try {
      final url = Uri.parse('${Env.apiBaseUrl}$path');
      final headers = await _getHeaders();

      print('🔍 GET ById');
      print('🌐 URL: $url');

      final response = await http.get(
        url,
        headers: headers,
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(response.body);

        if (jsonResponse is Map<String, dynamic>) {
          if (jsonResponse.containsKey('data') &&
              jsonResponse['data'] is Map<String, dynamic>) {
            return fromJson(jsonResponse['data']);
          }
          return fromJson(jsonResponse);
        }
      }

      return null;
    } catch (e) {
      print('❌ Error en getById: $e');
      rethrow;
    }
  }

  /// POST - Crear
  Future<T?> post<T>({
    required String path,
    required Map<String, dynamic> body,
    T Function(Map<String, dynamic> json)? fromJson,
  }) async {
    try {
      final url = Uri.parse('${Env.apiBaseUrl}$path');
      final headers = await _getHeaders();

      print('➕ POST');
      print('🌐 URL: $url');
      print('📦 Body: $body');

      final response = await http.post(
        url,
        headers: headers,
        body: jsonEncode(body),
      ).timeout(const Duration(seconds: 30));

      print('📊 Status: ${response.statusCode}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        if (fromJson != null) {
          final jsonResponse = jsonDecode(response.body);
          if (jsonResponse is Map<String, dynamic>) {
            if (jsonResponse.containsKey('data')) {
              return fromJson(jsonResponse['data']);
            }
            return fromJson(jsonResponse);
          }
        }
        return null;
      }

      throw Exception('Error HTTP: ${response.statusCode}');
    } catch (e) {
      print('❌ Error en post: $e');
      rethrow;
    }
  }
  /// Obtiene el ID del usuario logueado
Future<String?> getUserId() async {
  return await _authService.getUserId();
}

  /// Parsea la respuesta JSON
  List<T> _parseResponse<T>(
    String body,
    T Function(Map<String, dynamic> json) fromJson, {
    String? nestedKey,
  }) {
    try {
      final jsonResponse = jsonDecode(body);
      List<dynamic>? dataList;

      if (jsonResponse is Map<String, dynamic>) {
        // 1. Si hay nestedKey, buscar esa clave primero
        if (nestedKey != null && jsonResponse.containsKey(nestedKey)) {
          final nested = jsonResponse[nestedKey];
          if (nested is List) {
            dataList = nested;
            print('📂 Datos encontrados en clave: "$nestedKey"');
          }
        }
        // 2. Si no, buscar en 'data'
        else if (jsonResponse.containsKey('data')) {
          if (jsonResponse['data'] is List) {
            dataList = jsonResponse['data'];
          } else if (jsonResponse['data'] is Map) {
            // Buscar dentro de data: items, customers, records
            final dataMap = jsonResponse['data'] as Map<String, dynamic>;
            if (dataMap.containsKey('items')) {
              dataList = dataMap['items'];
            } else if (dataMap.containsKey('customers')) {
              dataList = dataMap['customers'];
            } else if (dataMap.containsKey('records')) {
              dataList = dataMap['records'];
            }
          }
        }
        // 3. Buscar otras claves comunes
        else if (jsonResponse.containsKey('customers')) {
          dataList = jsonResponse['customers'];
        } else if (jsonResponse.containsKey('items')) {
          dataList = jsonResponse['items'];
        } else if (jsonResponse.containsKey('results')) {
          dataList = jsonResponse['results'];
        }
      }
      // 4. Si la respuesta es directamente una lista
      else if (jsonResponse is List) {
        dataList = jsonResponse;
      }

      if (dataList != null) {
        final List<T> items = [];
        for (var item in dataList) {
          try {
            if (item is Map<String, dynamic>) {
              items.add(fromJson(item));
            }
          } catch (e) {
            print('⚠️ Error parseando item: $e');
          }
        }
        print('✅ ${items.length} items obtenidos');
        return items;
      }

      print('⚠️ Formato de respuesta no reconocido');
      print('📝 Body (primeros 300 chars): ${body.substring(0, body.length > 300 ? 300 : body.length)}');
      return [];
    } catch (e) {
      print('❌ Error parseando JSON: $e');
      return [];
    }
  }
}