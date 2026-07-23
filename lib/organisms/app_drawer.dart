import 'package:flutter/material.dart';
import '../core/app_colors.dart';
import '../atoms/avatar_widget.dart';
import '../pages/profile_page.dart';
import '../pages/clientes_page.dart';
import '../pages/catalogo_page.dart';
import '../pages/visitas_page.dart';
import '../pages/admin_panel_page.dart';
import '../pages/mapa_clientes_page.dart';
import '../pages/crear_pregunta_page.dart';

class AppDrawer extends StatelessWidget {
  final String userName;
  final String? userRole;
  final String? userPhoto;
  final String? userEmail;
  final VoidCallback onLogout;
  final VoidCallback? onProfileUpdated;

  const AppDrawer({
    super.key,
    required this.userName,
    required this.userRole,
    required this.userPhoto,
    required this.userEmail,
    required this.onLogout,
    this.onProfileUpdated,
  });

  String _getRoleName(String? role) {
    switch (role?.toLowerCase()) {
      case 'admin':
        return 'Administrador';
      case 'vendedor_foraneo':
        return 'Vendedor Foráneo';
      case 'vendedor':
      default:
        return 'Vendedor';
    }
  }

  bool _isAdmin(String? role) => role?.toLowerCase() == 'admin';
  bool _isVendedor(String? role) {
    final r = role?.toLowerCase();
    return r == 'vendedor' || r == 'vendedor_foraneo';
  }

  @override
  Widget build(BuildContext context) {
    final rol = userRole;

    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          // Header
          UserAccountsDrawerHeader(
            accountName: Text(
              userName,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            accountEmail: Text(_getRoleName(rol)),
            currentAccountPicture: AvatarWidget(
              name: userName,
              photoUrl: userPhoto,
            ),
            decoration: const BoxDecoration(color: AppColors.primaryColor),
          ),

          // Dashboard - Ambos roles
          ListTile(
            leading: const Icon(Icons.dashboard, color: AppColors.primaryColor),
            title: const Text('Dashboard'),
            onTap: () => Navigator.pop(context),
          ),

          // ─── ADMIN ───
          if (_isAdmin(rol))
            ListTile(
              leading: const Icon(Icons.admin_panel_settings, color: Colors.teal),
              title: const Text('Administración'),
              subtitle: const Text('Usuarios y Encuestas'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const AdminPanelPage()),
                );
              },
            ),

          // ─── VENDEDOR ───
          if (_isVendedor(rol)) ...[
            ListTile(
              leading: const Icon(Icons.people, color: AppColors.primaryColor),
              title: const Text('Clientes'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const ClientesPage()),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.inventory_2, color: AppColors.primaryColor),
              title: const Text('Catálogo de Productos'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const CatalogoPage()),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.assignment, color: AppColors.primaryColor),
              title: const Text('Mis Visitas'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const VisitasPage()),
                );
              },
            ),  
            // En la sección del vendedor:
            ListTile(
              leading: const Icon(Icons.map, color: Colors.teal),
              title: const Text('Mapa de Clientes'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const MapaClientesPage()),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.add_task, color: Colors.deepPurple),
              title: const Text('Crear Pregunta'),
              subtitle: const Text(
                'Añade preguntas a la encuesta (offline)',
                style: TextStyle(fontSize: 11),
              ),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const CrearPreguntaPage()),
                );
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.person_outline, color: AppColors.primaryColor),
              title: const Text('Mi Perfil'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const ProfilePage()),
                ).then((_) => onProfileUpdated?.call());
              },
            ),
          ],

          const Divider(),

          // Cerrar Sesión - Ambos
          ListTile(
            leading: const Icon(Icons.logout, color: AppColors.errorColor),
            title: const Text('Cerrar Sesión', style: TextStyle(color: AppColors.errorColor)),
            onTap: onLogout,
          ),
        ],
      ),
    );
  }
}