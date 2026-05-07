import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../core/app_colors.dart';
import '../molecules/stat_card.dart';
import '../molecules/dolar_indicator.dart';
import '../models/dolar_model.dart';
import '../pages/driver_page.dart';

class DashboardContent extends StatefulWidget {
  final String userName;
  final VoidCallback onScanPressed;
  final String userRole;

  const DashboardContent({
    super.key,
    required this.userName,
    required this.onScanPressed,
    required this.userRole,
  });

  @override
  State<DashboardContent> createState() => _DashboardContentState();
}

class _DashboardContentState extends State<DashboardContent> {
  Map<String, dynamic>? dolarData;

  // Helpers para verificar roles
  bool get _isAdmin => widget.userRole.toLowerCase() == 'superadmin';
  bool get _isGerente => widget.userRole.toLowerCase() == 'gerente';
  bool get _isVendedor => widget.userRole.toLowerCase() == 'vendedor';
  bool get _isChofer => widget.userRole.toLowerCase() == 'chofer';
  bool get _isAdminOrGerente => _isAdmin || _isGerente;
  bool get _canScan => _isAdmin || _isChofer;

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
          // --- 1. BARRA DE DÓLARES (Para TODOS) ---
          if (dolarData != null &&
              dolarData!['bcv'].isNotEmpty &&
              dolarData!['usdt'].isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 20),
              child: Row(
                children: [
                  Expanded(
                    child: DolarIndicator(
                      title: "Dólar BCV",
                      dolar: DolarModel.fromJson(
                          dolarData!['bcv'] as Map<String, dynamic>),
                      backgroundColor: Colors.greenAccent.shade700,
                    ),
                  ),
                  const SizedBox(width: 15),
                  Expanded(
                    child: DolarIndicator(
                      title: "USDT Paralelo",
                      dolar: DolarModel.fromJson(
                          dolarData!['usdt'] as Map<String, dynamic>),
                      backgroundColor: Colors.blueAccent.shade700,
                    ),
                  ),
                ],
              ),
            ),

          // --- 2. SALUDO ---
          Text(
            'Hola, ${widget.userName} 👋',
            style: const TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 10),

          // Subtítulo con rol
          Text(
            _getRoleDisplayName(),
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[500],
            ),
          ),
          const SizedBox(height: 30),

          // --- 3. TARJETAS POR ROL ---
          _buildRoleSpecificCards(),

          const SizedBox(height: 30),

          // --- 4. ACCIÓN PRINCIPAL (Escáner) ---
          // Solo para: Admin y Chofer
          if (_canScan)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.cardColor,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.08),
                    blurRadius: 15,
                  ),
                ],
              ),
              child: Column(
                children: [
                  const Text(
                    'Acciones Rápidas',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    height: 60,
                    child: ElevatedButton.icon(
                      onPressed: widget.onScanPressed,
                      icon: const Icon(Icons.qr_code_scanner, size: 28),
                      label: const Text(
                        'ESCANEAR CÓDIGO',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryColor,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
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

    // CHOFER
    if (_isChofer) {
      return StatCard(
        title: 'Viajes Asignados',
        value: 'Ver Mis Viajes',
        icon: Icons.local_shipping,
        iconColor: Colors.greenAccent,
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const DriverPage()),
          );
        },
      );
    }

    // ADMIN o GERENTE - Vista general con múltiples tarjetas
    if (_isAdminOrGerente) {
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
      case 'superadmin': return 'Administrador';
      case 'vendedor': return 'Vendedor';
      case 'gerente': return 'Gerente';
      case 'cliente': return 'Cliente';
      case 'chofer': return 'Chofer';
      case 'jefe de almacén': return 'Jefe de Almacén';
      default: return widget.userRole;
    }
  }
}