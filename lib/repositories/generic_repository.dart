import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:sqflite/sqflite.dart';
import '../core/env.dart';
import '../services/auth_service.dart';
import '../services/database_helper.dart';

class GenericRepository {
  final DatabaseHelper _db = DatabaseHelper.instance;
  final AuthService _authService = AuthService.instance;

  GenericRepository._();
  static final GenericRepository instance = GenericRepository._();

  // ═══════════════════════════════════════════════════════════════
  // MÉTODOS ONLINE (API) - Para productos, imágenes, etc.
  // ═══════════════════════════════════════════════════════════════

  /// Obtiene headers con autenticación para API
  Future<Map<String, String>> _getHeaders() async {
    final token = await _authService.getToken();
    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  /// GET - Obtener lista desde API
  Future<List<T>> getListOnline<T>({
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

      print('📋 GET List (API)');
      print('🌐 URL: $url');
      print('📂 NestedKey: ${nestedKey ?? "data"}');

      final response = await http.get(
        url,
        headers: headers,
      ).timeout(const Duration(seconds: 30));

      print('📊 Status: ${response.statusCode}');

      if (response.statusCode == 200) {
        return _parseResponse<T>(response.body, fromJson, nestedKey: nestedKey);
      }

      if (response.statusCode == 401) {
        await _authService.logout();
        throw Exception('Sesión expirada.');
      }

      print('❌ Error HTTP: ${response.statusCode}');
      return [];
    } catch (e) {
      print('❌ Error en getListOnline: $e');
      return [];
    }
  }

  /// GET - Obtener por ID desde API
  Future<T?> getByIdOnline<T>({
    required String path,
    required T Function(Map<String, dynamic> json) fromJson,
  }) async {
    try {
      final url = Uri.parse('${Env.apiBaseUrl}$path');
      final headers = await _getHeaders();

      print('🔍 GET ById (API)');
      print('🌐 URL: $url');

      final response = await http.get(
        url,
        headers: headers,
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(response.body);
        if (jsonResponse is Map<String, dynamic>) {
          if (jsonResponse.containsKey('data') && jsonResponse['data'] is Map<String, dynamic>) {
            return fromJson(jsonResponse['data']);
          }
          return fromJson(jsonResponse);
        }
      }
      return null;
    } catch (e) {
      print('❌ Error en getByIdOnline: $e');
      return null;
    }
  }

  /// POST - Crear en API
  Future<T?> postOnline<T>({
    required String path,
    required Map<String, dynamic> body,
    T Function(Map<String, dynamic> json)? fromJson,
  }) async {
    try {
      final url = Uri.parse('${Env.apiBaseUrl}$path');
      final headers = await _getHeaders();

      print('➕ POST (API)');
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
      print('❌ Error en postOnline: $e');
      return null;
    }
  }

  /// Ejecuta petición HTTP genérica (POST/PATCH/PUT/DELETE).
  /// Usado por SyncQueueService para drenar operaciones pendientes.
  Future<({int statusCode, String body})> executeRequest({
    required String method,
    required String endpoint,
    Map<String, dynamic>? payload,
    Duration timeout = const Duration(seconds: 30),
  }) async {
    final url = Uri.parse('${Env.apiBaseUrl}$endpoint');
    final headers = await _getHeaders();
    final encodedBody = payload == null ? null : jsonEncode(payload);

    http.Response response;
    switch (method.toUpperCase()) {
      case 'POST':
        response = await http.post(url, headers: headers, body: encodedBody).timeout(timeout);
        break;
      case 'PATCH':
        response = await http.patch(url, headers: headers, body: encodedBody).timeout(timeout);
        break;
      case 'PUT':
        response = await http.put(url, headers: headers, body: encodedBody).timeout(timeout);
        break;
      case 'DELETE':
        response = await http.delete(url, headers: headers).timeout(timeout);
        break;
      default:
        throw ArgumentError('Método HTTP no soportado: $method');
    }

    return (statusCode: response.statusCode, body: response.body);
  }

  /// Parsea respuesta JSON de API
  List<T> _parseResponse<T>(
    String body,
    T Function(Map<String, dynamic> json) fromJson, {
    String? nestedKey,
  }) {
    try {
      final jsonResponse = jsonDecode(body);
      List<dynamic>? dataList;

      if (jsonResponse is Map<String, dynamic>) {
        if (nestedKey != null && jsonResponse.containsKey(nestedKey)) {
          final nested = jsonResponse[nestedKey];
          if (nested is List) dataList = nested;
        } else if (jsonResponse.containsKey('data')) {
          if (jsonResponse['data'] is List) {
            dataList = jsonResponse['data'];
          } else if (jsonResponse['data'] is Map) {
            final dataMap = jsonResponse['data'] as Map<String, dynamic>;
            dataList = dataMap['items'] ?? dataMap['customers'] ?? dataMap['records'];
          }
        } else if (jsonResponse.containsKey('customers')) {
          dataList = jsonResponse['customers'];
        } else if (jsonResponse.containsKey('items')) {
          dataList = jsonResponse['items'];
        }
      } else if (jsonResponse is List) {
        dataList = jsonResponse;
      }

      if (dataList != null) {
        final List<T> items = [];
        for (var item in dataList) {
          if (item is Map<String, dynamic>) {
            items.add(fromJson(item));
          }
        }
        print('✅ ${items.length} items obtenidos de API');
        return items;
      }
      return [];
    } catch (e) {
      print('❌ Error parseando JSON: $e');
      return [];
    }
  }

  // ═══════════════════════════════════════════════════════════════
  // MÉTODOS LOCALES (SQLite) - Para clientes, visitas, encuestas
  // ═══════════════════════════════════════════════════════════════

  /// GET - Obtener lista desde SQLite
  Future<List<T>> getListLocal<T>({
    required String table,
    String? where,
    List<dynamic>? whereArgs,
    String? orderBy,
    int? limit,
    int? offset,
    required T Function(Map<String, dynamic> json) fromJson,
  }) async {
    try {
      final db = await _db.database;

      print('📋 GET List (Local)');
      print('📂 Tabla: $table');

      final results = await db.query(
        table,
        where: where,
        whereArgs: whereArgs,
        orderBy: orderBy,
        limit: limit,
        offset: offset,
      );

      final List<T> items = [];
      for (var row in results) {
        try {
          items.add(fromJson(row));
        } catch (e) {
          print('⚠️ Error parseando row: $e');
        }
      }

      print('✅ ${items.length} registros de $table');
      return items;
    } catch (e) {
      print('❌ Error en getListLocal: $e');
      return [];
    }
  }

  /// GET - Obtener por ID desde SQLite
  Future<T?> getByIdLocal<T>({
    required String table,
    required String id,
    String idColumn = 'id',
    required T Function(Map<String, dynamic> json) fromJson,
  }) async {
    try {
      final db = await _db.database;

      print('🔍 GET ById (Local)');
      print('📂 Tabla: $table, ID: $id');

      final results = await db.query(
        table,
        where: '$idColumn = ?',
        whereArgs: [id],
        limit: 1,
      );

      if (results.isNotEmpty) {
        return fromJson(results.first);
      }
      return null;
    } catch (e) {
      print('❌ Error en getByIdLocal: $e');
      return null;
    }
  }

  /// INSERT - Crear registro en SQLite
  Future<int> insertLocal({
    required String table,
    required Map<String, dynamic> data,
    String? id,
  }) async {
    try {
      final db = await _db.database;
      final insertData = Map<String, dynamic>.from(data);
      if (id != null) insertData['id'] = id;

      print('➕ INSERT (Local)');
      print('📂 Tabla: $table');

      final result = await db.insert(table, insertData);
      print('✅ Insertado ID: $result');
      return result;
    } catch (e) {
      print('❌ Error en insertLocal: $e');
      return -1;
    }
  }

  /// UPDATE - Actualizar en SQLite
  Future<int> updateLocal({
    required String table,
    required Map<String, dynamic> data,
    required String where,
    required List<dynamic> whereArgs,
  }) async {
    try {
      final db = await _db.database;

      print('✏️ UPDATE (Local)');
      print('📂 Tabla: $table');

      final result = await db.update(table, data, where: where, whereArgs: whereArgs);
      print('✅ Actualizados: $result');
      return result;
    } catch (e) {
      print('❌ Error en updateLocal: $e');
      return 0;
    }
  }

  /// DELETE - Eliminar en SQLite
  Future<int> deleteLocal({
    required String table,
    required String where,
    required List<dynamic> whereArgs,
  }) async {
    try {
      final db = await _db.database;

      print('🗑️ DELETE (Local)');
      print('📂 Tabla: $table');

      final result = await db.delete(table, where: where, whereArgs: whereArgs);
      print('✅ Eliminados: $result');
      return result;
    } catch (e) {
      print('❌ Error en deleteLocal: $e');
      return 0;
    }
  }

  /// RAW QUERY - Consulta SQL directa
  Future<List<Map<String, dynamic>>> rawQuery(String sql, [List<dynamic>? arguments]) async {
    try {
      final db = await _db.database;
      return await db.rawQuery(sql, arguments);
    } catch (e) {
      print('❌ Error en rawQuery: $e');
      return [];
    }
  }

  // ═══════════════════════════════════════════════════════════════
  // MÉTODOS GENÉRICOS (ENRUTAMIENTO DINÁMICO)
  // ═══════════════════════════════════════════════════════════════

  /// GET - Enrutamiento dinámico (Online si tiene path, Local si tiene table)
  Future<List<T>> getList<T>({
    String? path,
    String? table,
    Map<String, String>? queryParams,
    String? nestedKey,
    String? where,
    List<dynamic>? whereArgs,
    String? orderBy,
    int? limit,
    int? offset,
    required T Function(Map<String, dynamic> json) fromJson,
  }) async {
    if (path != null) {
      return getListOnline<T>(
        path: path,
        queryParams: queryParams,
        nestedKey: nestedKey,
        fromJson: fromJson,
      );
    } else if (table != null) {
      return getListLocal<T>(
        table: table,
        where: where,
        whereArgs: whereArgs,
        orderBy: orderBy,
        limit: limit,
        offset: offset,
        fromJson: fromJson,
      );
    } else {
      throw ArgumentError('Debe proporcionar un path (online) o una tabla (local).');
    }
  }

  /// GET BY ID - Enrutamiento dinámico (Online si tiene path, Local si tiene table)
  Future<T?> getById<T>({
    String? path,
    String? table,
    String? id,
    String idColumn = 'id',
    required T Function(Map<String, dynamic> json) fromJson,
  }) async {
    if (path != null) {
      return getByIdOnline<T>(
        path: path,
        fromJson: fromJson,
      );
    } else if (table != null && id != null) {
      return getByIdLocal<T>(
        table: table,
        id: id,
        idColumn: idColumn,
        fromJson: fromJson,
      );
    } else {
      throw ArgumentError('Debe proporcionar un path (online) o una tabla con ID (local).');
    }
  }

  /// INSERT - Guarda un registro localmente
  Future<int> insert({
    required String table,
    required Map<String, dynamic> data,
    String? id,
  }) async {
    return insertLocal(
      table: table,
      data: data,
      id: id,
    );
  }

  /// UPDATE - Actualiza un registro localmente
  Future<int> update({
    required String table,
    required Map<String, dynamic> data,
    required String where,
    required List<dynamic> whereArgs,
  }) async {
    return updateLocal(
      table: table,
      data: data,
      where: where,
      whereArgs: whereArgs,
    );
  }

  /// DELETE - Elimina un registro localmente
  Future<int> delete({
    required String table,
    required String where,
    required List<dynamic> whereArgs,
  }) async {
    return deleteLocal(
      table: table,
      where: where,
      whereArgs: whereArgs,
    );
  }

  /// Obtiene el ID del usuario logueado
  Future<String?> getUserId() async {
    return _authService.userId;
  }
}