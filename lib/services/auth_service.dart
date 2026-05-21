import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'database_helper.dart';

class AuthService {
  static final AuthService instance = AuthService._();
  AuthService._();

  final DatabaseHelper _db = DatabaseHelper.instance;

  static const String _userDataKey = 'user_data';
  static const String _isLoggedInKey = 'is_logged_in';

  Map<String, dynamic>? _currentUser;

  Map<String, dynamic>? get currentUser => _currentUser;
  bool get isLoggedIn => _currentUser != null;
  bool get isAdmin => _currentUser?['role'] == 'admin';
  bool get isVendedor => _currentUser?['role'] == 'vendedor';
  String? get userId => _currentUser?['id']?.toString();
  String? get userName => _currentUser?['full_name']?.toString();
  String? get userRole => _currentUser?['role']?.toString();

  Future<bool> login(String username, String password) async {
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
    }));
  }

  Future<String?> getToken() async => _currentUser?['id']?.toString();

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