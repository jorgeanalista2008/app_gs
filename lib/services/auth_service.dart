import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/login_response_model.dart';
import '../core/env.dart';

class AuthService {
  static const String _tokenKey = 'access_token';
  static const String _userDataKey = 'user_data';
  static const String _sessionIdKey = 'session_id';

Future<LoginResponseModel> login(String identifier, String password) async {
  final url = Uri.parse('${Env.apiBaseUrl}/auth/login');
  final response = await http.post(
    url,
    body: jsonEncode({'identifier': identifier, 'password': password}),
    headers: {'Content-Type': 'application/json'},
  );

  if (response.statusCode == 201) {
    // Directamente parsear la respuesta, sin verificar 'status'
    final loginResponse = LoginResponseModel.fromJson(jsonDecode(response.body));
    await _saveSession(loginResponse);
    return loginResponse;
  } else {
    final error = jsonDecode(response.body);
    throw Exception(error['message'] ?? 'Error de autenticación');
  }
}

  Future<void> _saveSession(LoginResponseModel response) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, response.accessToken);
    await prefs.setString(_sessionIdKey, response.sessionId);
    await prefs.setString(_userDataKey, jsonEncode({
      'id': response.user.id,
      'name': response.user.fullName,
      'email': response.user.email,
      'role': response.user.role.name,
      'photo': '', // Mostrar iniciales por defecto, editable por el usuario
      'branch_id': response.user.branchId,
      'tenant_id': response.user.tenantId,
    }));
  }

  Future<Map<String, dynamic>?> getUserData() async {
    final prefs = await SharedPreferences.getInstance();
    final userData = prefs.getString(_userDataKey);
    if (userData != null) {
      return jsonDecode(userData);
    }
    return null;
  }

  Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_tokenKey);
  }

  Future<bool> isLoggedIn() async {
    final token = await getToken();
    return token != null && token.isNotEmpty;
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    await prefs.remove(_userDataKey);
    await prefs.remove(_sessionIdKey);
  }

/// Obtiene el ID del usuario logueado
  Future<String?> getUserId() async {
    final prefs = await SharedPreferences.getInstance();
    final userData = prefs.getString(_userDataKey);
    if (userData != null) {
      final data = jsonDecode(userData);
      return data['id']?.toString();
    }
    return null;
  }

  /// Obtiene el tenant ID
  Future<String?> getTenantId() async {
    final prefs = await SharedPreferences.getInstance();
    final userData = prefs.getString(_userDataKey);
    if (userData != null) {
      final data = jsonDecode(userData);
      return data['tenant_id']?.toString();
    }
    return null;
  }
}