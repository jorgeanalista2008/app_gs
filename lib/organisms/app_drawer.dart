import 'package:app_gs/pages/history_page.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/app_colors.dart';
import '../atoms/avatar_widget.dart';
import '../pages/profile_page.dart';
import '../pages/manager_dashboard_page.dart';
import '../pages/billing_page.dart';
import '../pages/product_ranking_page.dart';
import '../pages/driver_page.dart'; // <--- IMPORTAR LA PÁGINA DEL CHOFER

class AppDrawer extends StatelessWidget {
  final String userName;
  final String? userRole;
  final String? userPhoto;
  final VoidCallback onLogout;
  final VoidCallback onScanPressed;

  const AppDrawer({
    super.key,
    required this.userName,
    required this.userRole,
    required this.userPhoto,
    required this.onLogout,
    required this.onScanPressed,
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
          
          // Opción: Dashboard (Home)
          ListTile(
            leading: const Icon(Icons.dashboard, color: AppColors.primaryColor),
            title: const Text('Dashboard'),
            onTap: () => Navigator.pop(context),
          ),
          
          // Opción: Escanear QR (para Admin y Chofer)
          if (userRole == '1' || userRole == '5')
           ListTile(
            leading: const Icon(Icons.qr_code_scanner, color: AppColors.primaryColor),
            title: const Text('Escanear Códigos'),
            onTap: () {
               Navigator.pop(context);
               onScanPressed();
            },
          ),
          
          // PERFIL (para todos los roles)
          ListTile(
            leading: const Icon(Icons.person_outline, color: AppColors.primaryColor),
            title: const Text('Mi Perfil'),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(context, MaterialPageRoute(
                builder: (context) => const ProfilePage()
              ));
            },
          ),
          
          // MIS RUTAS (EXCLUSIVO PARA CHOFER - Rol 5)
        /*  if (userRole == '5')
            ListTile(
              leading: const Icon(Icons.route, color: Colors.blueAccent), // Icono específico para rutas
              title: const Text('Mis Rutas'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(context, MaterialPageRoute(
                  builder: (context) => const DriverPage() // <--- NAVEGAR A LA PÁGINA DEL CHOFER
                ));
              },
            ),*/
          
          // Opción alternativa si quieres mantener la opción "Mis Rutas" donde estaba
          // (La opción anterior ya está en el menú pero sin navegación):
          if (userRole == '5')
            ListTile(
              leading: const Icon(Icons.local_shipping, color: AppColors.primaryColor),
              title: const Text('Mis viajes'),
              subtitle: const Text('Ver mis entregas asignadas'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(context, MaterialPageRoute(
                  builder: (context) => const DriverPage()
                ));
              },
            ),
            ListTile(
            leading: const Icon(Icons.history, color: AppColors.primaryColor),         
            title: const Text('Historial de Entregas'),
            onTap: () {
              Navigator.pop(context); // Cerrar drawer
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const HistoryPage()),
              );
            },
          ),
          
          // REPORTES GERENCIALES (Admin y Gerente)
          if (userRole == '1' || userRole == '3')
            ListTile(
              leading: const Icon(Icons.assessment, color: AppColors.primaryColor),
              title: const Text('Reportes Gerenciales'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(context, MaterialPageRoute(
                  builder: (context) => const ManagerDashboardPage()
                ));
              },
            ),
          
          // REPORTE FACTURACIÓN (Admin y Gerente)
          if (userRole == '1' || userRole == '3')
            ListTile(
              leading: const Icon(Icons.receipt_long, color: Colors.indigo),
              title: const Text('Reporte Facturación'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(context, MaterialPageRoute(
                  builder: (context) => const BillingPage()
                ));
              },
            ),
          
          // RANKING DE PRODUCTOS (Admin y Gerente)
          if (userRole == '1' || userRole == '3')
            ListTile(
              leading: const Icon(Icons.production_quantity_limits, color: Colors.indigo),
              title: const Text('Ranking de Productos'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(context, MaterialPageRoute(
                  builder: (context) => const ProductRankingPage()
                ));
              },
            ),
          
          // MIS PEDIDOS (Vendedor - Rol 2)
          if (userRole == '2')
            ListTile(
              leading: const Icon(Icons.shopping_cart, color: AppColors.primaryColor),
              title: const Text('Mis Pedidos'),
              onTap: () => Navigator.pop(context), // Aquí deberías navegar a la página de pedidos
            ),

          const Divider(),
          
          // CERRAR SESIÓN
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