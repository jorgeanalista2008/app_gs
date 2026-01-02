import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/app_colors.dart';
import '../atoms/avatar_widget.dart';
import '../pages/profile_page.dart'; // <--- ESTA ES LA IMPORTACIÓN QUE FALTABA
import '../pages/manager_dashboard_page.dart'; // <--- IMPORTANTE
import '../pages/billing_page.dart'; // <--- IMPORTANTE
import '../pages/product_ranking_page.dart'; // <--- IMPORTANTE

class AppDrawer extends StatelessWidget {
  final String userName;
  final String? userRole;
  final String? userPhoto;
  final VoidCallback onLogout;
  final VoidCallback onScanPressed; // <--- NUEVO PARÁMETRO

  const AppDrawer({
    super.key,
    required this.userName,
    required this.userRole,
    required this.userPhoto,
    required this.onLogout,
    required this.onScanPressed, // <--- AGREGAR AL CONSTRUCTOR
  });

  String _getRoleName(String? role) {
    switch (role) {
      case '1': return 'Administrador';
      case '2': return 'Vendedor';
      case '3': return 'Gerente';
      case '4': return 'Cliente';
      case '5': return 'Chofer';
      case '6': return 'Jefe de Almacén';
      default: return 'Usuario';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          UserAccountsDrawerHeader(
            accountName: Text(userName, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            accountEmail: Text(_getRoleName(userRole)),
            currentAccountPicture: AvatarWidget(name: userName, photoUrl: userPhoto),
            decoration: const BoxDecoration(color: AppColors.primaryColor),
          ),
          
          ListTile(
            leading: const Icon(Icons.dashboard, color: AppColors.primaryColor),
            title: const Text('Dashboard'),
            onTap: () => Navigator.pop(context),
          ),
          if (userRole == '1' || userRole == '5') // Admin y Chofer
           ListTile(
            leading: const Icon(Icons.qr_code_scanner, color: AppColors.primaryColor),
            title: const Text('Escanear Códigos'),
            onTap: () {
               Navigator.pop(context); // Cerrar drawer
               onScanPressed(); // <--- LLAMAR A LA FUNCIÓN DE NAVEGACIÓN
            },
          ),
          
          // AGREGAR ESTA LÍNEA: PERFIL
          ListTile(
            leading: const Icon(Icons.person_outline, color: AppColors.primaryColor), // Color distintivo
            title: const Text('Mi Perfil'),
            onTap: () {
              Navigator.pop(context); // Cerrar drawer
              Navigator.push(context, MaterialPageRoute(builder: (context) => const ProfilePage()));
            },
          ),
          if (userRole == '1' || userRole == '3') // Admin y Gerente
            ListTile(
              leading: const Icon(Icons.assessment, color: AppColors.primaryColor),
              title: const Text('Reportes Gerenciales'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(context, MaterialPageRoute(builder: (context) => const ManagerDashboardPage()));
              },
            ),
            if (userRole == '1' || userRole == '3')
            ListTile(
              leading: const Icon(Icons.receipt_long, color: Colors.indigo), // Icono distinto
              title: const Text('Reporte Facturación'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(context, MaterialPageRoute(builder: (context) => const BillingPage()));
              },
            ),
               if (userRole == '1' || userRole == '3')
            ListTile(
              leading: const Icon(Icons.production_quantity_limits, color: Colors.indigo), // Icono distinto
              title: const Text('Ranking de Productos'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(context, MaterialPageRoute(builder: (context) => const ProductRankingPage()));
              },
            ),
          if (userRole == '2')
            ListTile(
              leading: const Icon(Icons.shopping_cart, color: AppColors.primaryColor),
              title: const Text('Mis Pedidos'),
              onTap: () => Navigator.pop(context),
            ),

          if (userRole == '5')
            ListTile(
              leading: const Icon(Icons.local_shipping, color: AppColors.primaryColor),
              title: const Text('Mis Rutas'),
              onTap: () => Navigator.pop(context),
            ),

          const Divider(),
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