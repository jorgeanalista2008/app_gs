import 'package:flutter/material.dart';
import '../core/app_colors.dart';
import '../organisms/app_drawer.dart';
import '../organisms/dashboard_content.dart';
import '../services/auth_service.dart';
import 'login_page.dart';
import 'scanner_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final AuthService _authService = AuthService();
  String? _userName;
  String? _userRole;
  String? _userPhoto;
  String? _userEmail;
  bool _isLoading = true;

  // Helpers para verificar roles
  bool get _isAdmin => _userRole?.toLowerCase() == 'superadmin';
  bool get _isChofer => _userRole?.toLowerCase() == 'chofer';
  bool get _canScan => _isAdmin || _isChofer;

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
          _userEmail = userData['email'];
          _isLoading = false;
        });
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

  void _goToScanner() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const ScannerPage()),
    );
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
        actions: [
          // Icono de scanner SOLO para Admin y Chofer
          if (_canScan)
            IconButton(
              icon: const Icon(Icons.qr_code_scanner),
              onPressed: _goToScanner,
              tooltip: 'Escanear QR',
            ),
        ],
      ),
      drawer: AppDrawer(
        userName: _userName ?? 'Usuario',
        userRole: _userRole,
        userPhoto: _userPhoto,
        userEmail: _userEmail,
        onLogout: _logout,
        onScanPressed: _goToScanner,
      ),
      body: DashboardContent(
        userName: _userName ?? 'Usuario',
        userRole: _userRole ?? 'Usuario',
        onScanPressed: _goToScanner,
      ),
    );
  }
}