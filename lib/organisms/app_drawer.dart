import 'package:flutter/material.dart';
import '../core/app_colors.dart';
import '../atoms/avatar_widget.dart';
import '../pages/profile_page.dart';
import '../pages/clientes_page.dart';
import '../pages/catalogo_page.dart';
import '../pages/visitas_page.dart';
import '../pages/admin_panel_page.dart';
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

  // Mapeo de roles por nombre
  String _getRoleName(String? role) {
    switch (role?.toLowerCase()) {
      case 'superadmin':
      case 'admin':
        return 'Administrador';
      case 'vendedor':
      default:
        return 'Vendedor';
    }
  }

  // Helpers como MÉTODOS que reciben el rol
  bool _isAdmin(String? role) => role?.toLowerCase() == 'superadmin' || role?.toLowerCase() == 'admin';
  bool _isVendedor(String? role) => role?.toLowerCase() == 'vendedor';

  @override
  Widget build(BuildContext context) {
    // Guardar en variables locales para usar en el build
    final rol = userRole;
    print('=== APP DRAWER ===');
    print('userRole: $userRole');
    print('isAdmin: ${_isAdmin(userRole)}');
    print('isVendedor: ${_isVendedor(userRole)}');
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          // Header con datos del usuario
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

          // Dashboard (Home) - Para todos
          ListTile(
            leading: const Icon(Icons.dashboard, color: AppColors.primaryColor),
            title: const Text('Dashboard'),
            onTap: () => Navigator.pop(context),
          ),

          // Mi Perfil - Para todos
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

          // Clientes - Admin, Vendedor
          if (_isAdmin(rol) || _isVendedor(rol))
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

          // Panel de Administración - Solo Admin/Superadmin
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

            // Catálogo de Productos - Admin, Vendedor
            if (_isAdmin(rol) || _isVendedor(rol))
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

          // Mis Pedidos - Vendedor
          if (_isVendedor(rol))
            ListTile(
              leading: const Icon(Icons.shopping_cart, color: AppColors.primaryColor),
              title: const Text('Mis Pedidos'),
              onTap: () => Navigator.pop(context),
            ),

                      // Visitas - Vendedor
          if (_isVendedor(rol))
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

          const Divider(),

          // Cerrar Sesión
          ListTile(
            leading: const Icon(Icons.logout, color: AppColors.errorColor),
            title: const Text(
              'Cerrar Sesión',
              style: TextStyle(color: AppColors.errorColor),
            ),
            onTap: onLogout,
          ),
        ],
      ),
    );
  }
}