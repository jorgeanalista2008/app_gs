import 'package:app_gs/pages/history_page.dart';
import 'package:flutter/material.dart';
import '../core/app_colors.dart';
import '../atoms/avatar_widget.dart';
import '../pages/profile_page.dart';
import '../pages/manager_dashboard_page.dart';
import '../pages/billing_page.dart';
import '../pages/product_ranking_page.dart';
import '../pages/driver_page.dart';
import '../pages/clientes_page.dart';
import '../pages/articulos_page.dart';
import '../pages/catalogo_page.dart';
import '../pages/visitas_page.dart';
class AppDrawer extends StatelessWidget {
  final String userName;
  final String? userRole;
  final String? userPhoto;
  final String? userEmail;
  final VoidCallback onLogout;
  final VoidCallback onScanPressed;

  const AppDrawer({
    super.key,
    required this.userName,
    required this.userRole,
    required this.userPhoto,
    required this.userEmail,
    required this.onLogout,
    required this.onScanPressed,
  });

  // Mapeo de roles por nombre
  String _getRoleName(String? role) {
    switch (role?.toLowerCase()) {
      case 'superadmin': return 'Administrador';
      case 'vendedor': return 'Vendedor';
      case 'gerente': return 'Gerente';
      case 'cliente': return 'Cliente';
      case 'chofer': return 'Chofer';
      case 'jefe de almacén': return 'Jefe de Almacén';
      default: return role ?? 'Usuario';
    }
  }

  // Helpers como MÉTODOS que reciben el rol
  bool _isAdmin(String? role) => role?.toLowerCase() == 'superadmin';
  bool _isGerente(String? role) => role?.toLowerCase() == 'gerente';
  bool _isVendedor(String? role) => role?.toLowerCase() == 'vendedor';
  bool _isChofer(String? role) => role?.toLowerCase() == 'chofer';
  bool _isAdminOrGerente(String? role) => _isAdmin(role) || _isGerente(role);
  bool _isAdminOrChofer(String? role) => _isAdmin(role) || _isChofer(role);

  @override
  Widget build(BuildContext context) {
    // Guardar en variables locales para usar en el build
    final rol = userRole;
    print('=== APP DRAWER ===');
  print('userRole: $userRole');
  print('isAdmin: ${_isAdmin(userRole)}');
  print('isVendedor: ${_isVendedor(userRole)}');
  print('isGerente: ${_isGerente(userRole)}');
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

          // Escanear QR - Admin y Chofer
          if (_isAdminOrChofer(rol))
            ListTile(
              leading: const Icon(Icons.qr_code_scanner, color: AppColors.primaryColor),
              title: const Text('Escanear Códigos'),
              onTap: () {
                Navigator.pop(context);
                onScanPressed();
              },
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
              );
            },
          ),

          // Clientes - Admin, Gerente, Vendedor
          if (_isAdmin(rol) || _isGerente(rol) || _isVendedor(rol))
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

        

          // Mis Viajes - Exclusivo Chofer
          if (_isChofer(rol))
            ListTile(
              leading: const Icon(Icons.local_shipping, color: AppColors.primaryColor),
              title: const Text('Mis viajes'),
              subtitle: const Text('Ver mis entregas asignadas'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const DriverPage()),
                );
              },
            ),

          // Historial de Entregas - Chofer
          if (_isChofer(rol))
            ListTile(
              leading: const Icon(Icons.history, color: AppColors.primaryColor),
              title: const Text('Historial de Entregas'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const HistoryPage()),
                );
              },
            ),

          // Reportes Gerenciales - Admin y Gerente
          if (_isAdminOrGerente(rol))
            ListTile(
              leading: const Icon(Icons.assessment, color: AppColors.primaryColor),
              title: const Text('Reportes Gerenciales'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const ManagerDashboardPage()),
                );
              },
            ),

          // Reporte Facturación - Admin y Gerente
          if (_isAdminOrGerente(rol))
            ListTile(
              leading: const Icon(Icons.receipt_long, color: Colors.indigo),
              title: const Text('Reporte Facturación'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const BillingPage()),
                );
              },
            ),


            // Catálogo de Productos - Admin, Gerente, Vendedor
            if (_isAdmin(rol) || _isGerente(rol) || _isVendedor(rol))
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