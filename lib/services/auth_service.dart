import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'database_helper.dart';
import 'connectivity_service.dart';
import '../repositories/generic_repository.dart';

class AuthService {
  static final AuthService instance = AuthService._();
  AuthService._();

  final DatabaseHelper _db = DatabaseHelper.instance;

  static const String _userDataKey = 'user_data';
  static const String _isLoggedInKey = 'is_logged_in';

  Map<String, dynamic>? _currentUser;
  String? _onlineToken;

  String? get onlineToken => _onlineToken;
  set onlineToken(String? token) => _onlineToken = token;

  Map<String, dynamic>? get currentUser => _currentUser;
  bool get isLoggedIn => _currentUser != null;
  bool get isAdmin => _currentUser?['role'] == 'admin';
  bool get isVendedor => _currentUser?['role'] == 'vendedor';
  String? get userId => _currentUser?['id']?.toString();
  String? get userName => _currentUser?['full_name']?.toString();
  String? get userRole => _currentUser?['role']?.toString();

  Future<bool> login(String username, String password) async {
    final connected = await ConnectivityService.instance.isConnected();
    if (connected) {
      try {
        print('🌐 Dispositivo conectado. Intentando login online para $username...');
        final response = await GenericRepository.instance.postOnline<Map<String, dynamic>>(
          path: '/auth/login',
          body: {
            'identifier': username,
            'password': password,
          },
          fromJson: (json) => json,
        );

        if (response != null) {
          final token = response['access_token'] ?? response['token'] ??
                        (response['data'] is Map ? (response['data']['access_token'] ?? response['data']['token']) : null);
          final userMap = response['user'] ?? 
                          (response['data'] is Map ? response['data']['user'] : null);
          if (token != null && userMap != null) {
            _onlineToken = token.toString();
            final userId = userMap['id']?.toString() ?? '';
            final fullName = userMap['full_name']?.toString() ?? '';
            final role = userMap['role']?['name']?.toString().toLowerCase() ?? 'vendedor';
            final tenantId = userMap['tenant_id']?.toString();
            final companyId = userMap['company_id']?.toString() ?? userMap['tenant_id']?.toString();
            final branchId = userMap['branch_id']?.toString();

            // Guardar o actualizar en SQLite local
            await _db.guardarOActualizarUsuario(
              id: userId,
              username: username,
              password: password,
              fullName: fullName,
              role: role,
              tenantId: tenantId,
              companyId: companyId,
              branchId: branchId,
            );

            // Cargar de SQLite para tener el objeto completo listo
            final localUser = await _db.getUsuario(userId);
            if (localUser != null) {
              _currentUser = localUser;
              await _saveSession(localUser);
              print('✅ Login online y sincronización local exitosa para $username');
              return true;
            }
          }
        }
      } catch (e) {
        print('⚠️ Error en login online (intentando login local): $e');
      }
    }

    // Fallback o login local
    print('🔑 Intentando login local para $username...');
    final user = await _db.login(username, password);
    if (user != null) {
      _currentUser = user;
      await _saveSession(user);
      return true;
    }
    return false;
  }

  Future<void> logout() async {
    _currentUser = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_userDataKey);
    await prefs.setBool(_isLoggedInKey, false);
  }

  Future<bool> tryAutoLogin() async {
    final prefs = await SharedPreferences.getInstance();
    final isLoggedIn = prefs.getBool(_isLoggedInKey) ?? false;
    if (isLoggedIn) {
      final userData = prefs.getString(_userDataKey);
      if (userData != null) {
        try {
          final user = jsonDecode(userData) as Map<String, dynamic>;
          final dbUser = await _db.getUsuario(user['id']?.toString() ?? '');
          if (dbUser != null && dbUser['activo'] == 1) {
            _currentUser = dbUser;
            return true;
          }
        } catch (e) {
          print('Error restaurando sesión: $e');
        }
      }
    }
    return false;
  }

  Future<void> _saveSession(Map<String, dynamic> user) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_isLoggedInKey, true);
    await prefs.setString(_userDataKey, jsonEncode({
      'id': user['id'],
      'username': user['username'],
      'full_name': user['full_name'],
      'role': user['role'],
      'tenant_id': user['tenant_id'],
      'company_id': user['company_id'],
      'branch_id': user['branch_id'],
    }));
  }

  Future<void> updateLocalSession(Map<String, dynamic> user) async {
    _currentUser = user;
    await _saveSession(user);
  }

  Future<String?> getToken() async => _onlineToken ?? _currentUser?['id']?.toString();

  Future<Map<String, dynamic>?> getUserData() async {
    if (_currentUser == null) return null;
    return {
      'id': _currentUser!['id'],
      'name': _currentUser!['full_name'],
      'email': _currentUser!['username'],
      'role': _currentUser!['role'],
      'photo': 'user.png',
    };
  }
}