import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/auth_service.dart';

class AuthState {
  final Map<String, dynamic>? currentUser;
  final bool isLoggedIn;

  const AuthState({this.currentUser, this.isLoggedIn = false});

  String? get userId => currentUser?['id']?.toString();
  String? get userName => currentUser?['full_name']?.toString();
  String? get userRole => currentUser?['role']?.toString();
  bool get isAdmin => userRole?.toLowerCase() == 'admin';
  bool get isVendedor {
    final r = userRole?.toLowerCase();
    return r == 'vendedor' || r == 'vendedor_foraneo';
  }
  bool get isForaneo => userRole?.toLowerCase() == 'vendedor_foraneo';
}

class AuthNotifier extends StateNotifier<AuthState> {
  AuthNotifier() : super(const AuthState()) {
    _syncFromService();
  }

  final AuthService _service = AuthService.instance;

  void _syncFromService() {
    final user = _service.currentUser;
    state = AuthState(currentUser: user, isLoggedIn: _service.isLoggedIn);
  }

  Future<bool> login(String username, String password) async {
    final ok = await _service.login(username, password);
    _syncFromService();
    return ok;
  }

  Future<bool> tryAutoLogin() async {
    final ok = await _service.tryAutoLogin();
    _syncFromService();
    return ok;
  }

  Future<void> logout() async {
    await _service.logout();
    _syncFromService();
  }

  /// Refresca estado desde singleton (útil tras editar perfil).
  void refresh() => _syncFromService();
}

final authStateProvider =
    StateNotifierProvider<AuthNotifier, AuthState>((ref) => AuthNotifier());
