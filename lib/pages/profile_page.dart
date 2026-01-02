import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/app_colors.dart';
import '../molecules/profile_header.dart';
import '../molecules/profile_option_item.dart';
import 'login_page.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  String? _userName;
  String? _userRole;
  String? _userPhoto;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  void _loadUserData() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _userName = prefs.getString('user_name') ?? 'Usuario';
      _userRole = prefs.getString('user_role');
      _userPhoto = prefs.getString('user_photo');
    });
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
            onPressed: () async { // <--- 1. AGREGA 'async' AQUÍ
              Navigator.pop(context); // Cerrar dialogo
              final prefs = await SharedPreferences.getInstance(); // <--- 2. AGREGA 'await' AQUÍ
              await prefs.clear(); // Borrar datos (agregué await para seguridad)
              
              if(mounted) {
                Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const LoginPage()));
              }
            },
            child: const Text('Salir', style: TextStyle(color: AppColors.errorColor)),
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
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Módulo de edición de perfil en desarrollo')),
                );
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
            )
          ],
        ),
      ),
    );
  }
}