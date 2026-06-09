import 'package:flutter/material.dart';
import '../core/app_colors.dart';
import '../organisms/app_drawer.dart';
import '../organisms/dashboard_content.dart';
import '../services/auth_service.dart';
import 'login_page.dart';
import '../atoms/sync_status_chip.dart';
import '../organisms/connection_wrapper.dart';
import '../services/sync_service.dart';
import '../services/connectivity_service.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final AuthService _authService = AuthService.instance;

  String? _userName;
  String? _userRole;
  String? _userPhoto;
  String? _userEmail;
  bool _isLoading = true;

  // Helpers para verificar roles (modo local: admin y vendedor)
  bool get _isAdmin => _authService.isAdmin;
  bool get _isVendedor => _authService.isVendedor;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  void _loadUserData() async {
    try {
      final userData = await _authService.getUserData();
      if (userData != null && mounted) {
        setState(() {
          _userName = userData['name'] ?? 'Usuario';
          _userRole = userData['role'] ?? 'Usuario';
          _userPhoto = userData['photo'] ?? 'user.png';
          _userEmail = userData['email'] ?? '';
          _isLoading = false;
        });

        print('=== HOME PAGE ===');
        print('Usuario: $_userName');
        print('Rol: $_userRole');
        print('Es admin: $_isAdmin');
        print('================');

        // Disparar sincronización completa automática en background si hay red
        final online = await ConnectivityService.instance.isConnected();
        if (online) {
          SyncService.instance.ejecutarSincronizacionCompleta();
        }
      } else {
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const LoginPage()),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al cargar datos: $e'),
            backgroundColor: AppColors.errorColor,
          ),
        );
      }
    }
  }

  void _logout() async {
    try {
      await _authService.logout();
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const LoginPage()),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al cerrar sesión: $e'),
            backgroundColor: AppColors.errorColor,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(
            color: AppColors.primaryColor,
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Inicio'),
        backgroundColor: AppColors.primaryColor,
        foregroundColor: Colors.white,
        actions: const [
          Padding(
            padding: EdgeInsets.symmetric(vertical: 12.0, horizontal: 16.0),
            child: SyncStatusChip(),
          ),
        ],
      ),
      drawer: AppDrawer(
        userName: _userName ?? 'Usuario',
        userRole: _userRole,
        userPhoto: _userPhoto,
        userEmail: _userEmail,
        onLogout: _logout,
      ),
      body: ConnectionWrapper(
        child: DashboardContent(
          userName: _userName ?? 'Usuario',
          userRole: _userRole ?? 'Usuario',
        ),
      ),
    );
  }
}