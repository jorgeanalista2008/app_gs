import 'package:flutter/material.dart';
import '../core/app_colors.dart';
import '../molecules/profile_header.dart';
import '../molecules/profile_option_item.dart';
import '../services/auth_service.dart';
import 'login_page.dart';
import 'account_info_page.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final AuthService _authService = AuthService.instance;

  String? _userName;
  String? _userRole;
  String? _userPhoto;
  String? _userEmail;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  void _loadUserData() async {
    final userData = await _authService.getUserData();
    if (userData != null && mounted) {
      setState(() {
        _userName = userData['name'] ?? 'Usuario';
        _userRole = userData['role'] == 'admin' ? 'Administrador' : 'Vendedor';
        _userPhoto = userData['photo'];
        _userEmail = userData['email'];
      });
    }
  }

  void _logout() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cerrar Sesión'),
        content: const Text('¿Estás seguro de que quieres salir de la aplicación?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context); // Cerrar diálogo
              await _authService.logout();
              if (mounted) {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (context) => const LoginPage()),
                );
              }
            },
            child: const Text(
              'Salir',
              style: TextStyle(color: AppColors.errorColor),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundColor,
      appBar: AppBar(
        title: const Text('Mi Perfil'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black87),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Molécula: Header
            ProfileHeader(
              userName: _userName ?? 'Usuario',
              userRole: _userRole,
              userPhoto: _userPhoto,
            ),

            const SizedBox(height: 30),

            // Sección: Cuenta
            ProfileOptionItem(
              icon: Icons.person,
              title: 'Información de Cuenta',
              subtitle: 'Ver y editar datos personales',
              iconColor: AppColors.primaryColor,
              onTap: () async {
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const AccountInfoPage()),
                );
                if (result == true) {
                  _loadUserData();
                }
              },
            ),

            // Sección: Seguridad
            ProfileOptionItem(
              icon: Icons.security,
              title: 'Seguridad',
              subtitle: 'Cambiar contraseña y datos de acceso',
              iconColor: Colors.orangeAccent,
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Módulo de seguridad en desarrollo')),
                );
              },
            ),

            // Sección: Soporte
            ProfileOptionItem(
              icon: Icons.support_agent,
              title: 'Ayuda y Soporte',
              subtitle: 'Contactar con soporte técnico',
              iconColor: Colors.greenAccent,
              onTap: () {},
            ),

            const SizedBox(height: 30),

            // Sección: Logout (Rojo)
            ProfileOptionItem(
              icon: Icons.logout,
              title: 'Cerrar Sesión',
              onTap: _logout,
              iconColor: AppColors.errorColor,
            ),

            const SizedBox(height: 20),
            Text(
              'Versión de la App 1.0.0',
              style: TextStyle(color: Colors.grey[400], fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}