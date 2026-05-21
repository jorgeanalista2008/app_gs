import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../core/app_colors.dart';
import '../molecules/stat_card.dart';


class DashboardContent extends StatefulWidget {
  final String userName;
  final String userRole;

  const DashboardContent({
    super.key,
    required this.userName,
    required this.userRole,
  });

  @override
  State<DashboardContent> createState() => _DashboardContentState();
}

class _DashboardContentState extends State<DashboardContent> {
  Map<String, dynamic>? dolarData;

  // Helpers para verificar roles
  bool get _isAdmin => widget.userRole.toLowerCase() == 'superadmin' || widget.userRole.toLowerCase() == 'admin';
  bool get _isVendedor => widget.userRole.toLowerCase() == 'vendedor';

  @override
  void initState() {
    super.initState();
    _fetchDolares();
  }

  Future<void> _fetchDolares() async {
    try {
      final response = await http.get(Uri.parse('https://ve.dolarapi.com/v1/dolares'));

      if (response.statusCode == 200) {
        List<dynamic> jsonList = jsonDecode(response.body);

        setState(() {
          dolarData = {
            'bcv': jsonList.firstWhere(
              (e) => e['fuente'] == 'oficial',
              orElse: () => {},
            ),
            'usdt': jsonList.firstWhere(
              (e) => e['fuente'] == 'paralelo',
              orElse: () => {},
            ),
          };
        });
      }
    } catch (e) {
      // Error silencioso para no romper el Dashboard
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
     
          _buildRoleSpecificCards(),

          const SizedBox(height: 30),
        ],
      ),
    );
  }

  // Construye las tarjetas específicas según el rol
  Widget _buildRoleSpecificCards() {
    // VENDEDOR
    if (_isVendedor) {
      return StatCard(
        title: 'Pedidos Pendientes',
        value: 'Ver Mis Pedidos',
        icon: Icons.inventory_2,
        iconColor: Colors.orangeAccent,
        onTap: () {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Navegando a Mis Pedidos (Vendedor)...')),
          );
        },
      );
    }

    // ADMIN - Vista general con múltiples tarjetas
    if (_isAdmin) {
      return Column(
        children: [
          Row(
            children: [
              Expanded(
                child: StatCard(
                  title: 'Ventas Totales',
                  value: 'Cargando...',
                  icon: Icons.trending_up,
                  iconColor: Colors.green,
                  onTap: () {},
                ),
              ),
              const SizedBox(width: 15),
              Expanded(
                child: StatCard(
                  title: 'Pedidos',
                  value: 'Cargando...',
                  icon: Icons.shopping_cart,
                  iconColor: Colors.blue,
                  onTap: () {},
                ),
              ),
            ],
          ),
          const SizedBox(height: 15),
          Row(
            children: [
              Expanded(
                child: StatCard(
                  title: 'Clientes Nuevos',
                  value: 'Cargando...',
                  icon: Icons.person_add,
                  iconColor: Colors.purple,
                  onTap: () {},
                ),
              ),
              const SizedBox(width: 15),
              Expanded(
                child: StatCard(
                  title: 'Productos',
                  value: 'Ver Ranking',
                  icon: Icons.star,
                  iconColor: Colors.amber,
                  onTap: () {},
                ),
              ),
            ],
          ),
        ],
      );
    }

    // OTROS ROLES (Cliente, etc.)
    return const Text(
      "Vista General",
      style: TextStyle(fontSize: 16, color: Colors.grey),
    );
  }

  // Nombre descriptivo del rol
  String _getRoleDisplayName() {
    switch (widget.userRole.toLowerCase()) {
      case 'superadmin':
      case 'admin':
        return 'Administrador';
      case 'vendedor':
      default:
        return 'Vendedor';
    }
  }
}