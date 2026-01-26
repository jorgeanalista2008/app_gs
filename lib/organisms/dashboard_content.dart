import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../core/app_colors.dart';
import '../molecules/stat_card.dart';
import '../molecules/dolar_indicator.dart';
import '../models/dolar_model.dart';
import '../pages/driver_page.dart'; // <--- IMPORTAR LA PÁGINA DEL CHOFER

class DashboardContent extends StatefulWidget {
  final String userName;
  final VoidCallback onScanPressed;
  final String userRole; // <--- NUEVO PARAMETRO: Recibir el rol

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

  @override
  void initState() {
    super.initState();
    _fetchDolares();
  }
  Future<void> _fetchDolares() async {
    try {
      final response = await http.get(Uri.parse('https://ve.dolarapi.com/v1/dolares'));
      
      if (response.statusCode == 200) {
        // CORRECCIÓN: Decodificamos como List<dynamic> directamente
        // Esto evita errores de tipado estricto si la API varía levemente
        List<dynamic> jsonList = jsonDecode(response.body);
        
        setState(() {
          dolarData = {
            'bcv': jsonList.firstWhere(
              (e) => e['fuente'] == 'oficial', 
              orElse: () => {}
            ),
            'usdt': jsonList.firstWhere(
              (e) => e['fuente'] == 'paralelo', 
              orElse: () => {}
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
          if (dolarData != null && dolarData!['bcv'].isNotEmpty && dolarData!['usdt'].isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 20),
              child: Row(
                children: [
                  Expanded(
                    child: DolarIndicator(
                      title: "Dólar BCV", 
                      dolar: DolarModel.fromJson(dolarData!['bcv'] as Map<String, dynamic>), // CORRECCIÓN AQUÍ
                      backgroundColor: Colors.greenAccent.shade700,
                    ),
                  ),
                  const SizedBox(width: 15),
                
                ],
              ),
            ),

          // --- 2. SALUDO ---
          Text('Hola, ${widget.userName} 👋', style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
          const SizedBox(height: 30),

          // --- 3. TARJETAS POR ROL (Lógica Condicional) ---
          if (widget.userRole == '2') ...[
            // --- VENDEDOR (SOLO VE PEDIDOS) ---
            StatCard(
              title: 'Pedidos Pendientes', 
              value: 'Ver Mis Pedidos', // Placeholder texto
              icon: Icons.inventory_2, 
              iconColor: Colors.orangeAccent,
              onTap: () {
                // Aquí irá la navegación a la página de pedidos
                // Navigator.push(..., SellerOrdersPage());
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Navegando a Mis Pedidos (Vendedor)...')),
                );
              },
            ),
          ] else if (widget.userRole == '5') ...[
            // --- CHOFER (SOLO VE RUTAS) ---
            StatCard(
              title: 'Viajes Asignados', 
              value: 'Ver Mis viajes', // Placeholder texto
              icon: Icons.local_shipping, 
              iconColor: Colors.greenAccent,
              onTap: () {
                 Navigator.push(context, MaterialPageRoute(
                    builder: (context) => const DriverPage()
                  ));
              },
            ),
          ] else ...[
            // --- ADMIN/GERENTE (O VER TODOS SI QUIERES) ---
            // Opcional: Si Admin/Gerente deben ver ambos, puedes duplicar las tarjetas aquí.
            // Por ahora, no mostramos tarjetas de pedidos/rutas para Admin/Gerente, o mostramos ambas.
            const Text("Vista General", style: TextStyle(fontSize: 16, color: Colors.grey)),
          ],

          const SizedBox(height: 30),

          // --- 4. ACCIÓN PRINCIPAL (Escáner) ---
          // SOLO SE MUESTRA PARA CHOFER(5), ADMIN(1) y GERENTE(3).
          // SE OCULTA PARA VENDEDOR(2) según tu petición.
          if ((widget.userRole == '5')) // Si NO es vendedor o gerente, muestra botón escáner
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.cardColor,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 15)],
              ),
              child: Column(
                children: [
                  const Text('Acciones Rápidas', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    height: 60,
                    child: ElevatedButton.icon(
                      onPressed: widget.onScanPressed,
                      icon: const Icon(Icons.qr_code_scanner, size: 28),
                      label: const Text('ESCANEAR CÓDIGO', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryColor,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
}