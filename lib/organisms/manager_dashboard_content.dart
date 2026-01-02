import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../core/app_colors.dart';
import '../models/dashboard_model.dart';
import '../molecules/sales_chart_widget.dart';
import '../molecules/transaction_row.dart';

class ManagerDashboardContent extends StatefulWidget {
  const ManagerDashboardContent({super.key});

  @override
  State<ManagerDashboardContent> createState() => _ManagerDashboardContentState();
}

class _ManagerDashboardContentState extends State<ManagerDashboardContent> {
  DashboardModel? dashboardData;
  bool isLoading = true;
  String? errorMessage;

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    try {
      final response = await http.get(
        Uri.parse('https://app.grupo-solsumed.com/api/get_manager_dashboard.php'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(response.body);
        if (jsonResponse['status'] == 'success') {
          setState(() {
            dashboardData = DashboardModel.fromJson(jsonResponse['data']);
            isLoading = false;
          });
        } else {
          setState(() {
            errorMessage = jsonResponse['message'];
            isLoading = false;
          });
        }
      } else {
        setState(() {
          errorMessage = "Error del servidor";
          isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        errorMessage = e.toString();
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator(color: AppColors.primaryColor));
    }

    if (errorMessage != null) {
      return Center(child: Text("Error: $errorMessage"));
    }

    // Si tenemos datos:
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Gerencia', style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: AppColors.primaryColor)),
          const SizedBox(height: 20),

          // 1. WIDGETS DE RESUMEN (DATOS DINÁMICOS)
          Row(
            children: [
              Expanded(
                child: _buildStatCard('Facturaciones', 'USD. ${dashboardData!.totalSales.toStringAsFixed(0)}', Icons.monetization_on, Colors.green),
              ),
              const SizedBox(width: 15),
              Expanded(
                child: _buildStatCard('Despachos', '${dashboardData!.totalOrders}', Icons.shopping_cart, Colors.blue),
              ),
              const SizedBox(width: 15),
              Expanded(
                child: _buildStatCard('Nuevos', '${dashboardData!.newClients}', Icons.person_add, Colors.orange),
              ),
            ],
          ),
          
          const SizedBox(height: 30),

          // 2. GRÁFICA PRINCIPAL (DATOS DINÁMICOS)
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.cardColor,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Rendimiento Mensual', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 20),
                SalesChartWidget(data: dashboardData!.chartData), // <--- PASAMOS LOS DATOS
              ],
            ),
          ),

          const SizedBox(height: 30),

          // 3. TABLA DE TRANSACCIONES (DATOS DINÁMICOS)
          const Text('Últimas Transacciones', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 15),
          
          // Generamos la lista dinámica de filas
          ...dashboardData!.transactions.map((tx) => TransactionRow(
            id: tx.id,
            client: tx.client,
            amount: tx.amount,
            status: tx.status,
            isPositive: tx.status == 'Completado',
          )).toList(),
          
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.cardColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 30),
          const SizedBox(height: 10),
          Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
          Text(title, style: const TextStyle(fontSize: 12, color: Colors.grey)),
        ],
      ),
    );
  }
}