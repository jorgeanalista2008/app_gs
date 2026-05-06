import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../core/app_colors.dart';
import '../models/billing_model.dart';
import '../molecules/seller_performance_card.dart';
import '../molecules/stat_card.dart'; // Reutilizamos la molécula genérica si quieres, o usamos cards manuales

class BillingContent extends StatefulWidget {
  const BillingContent({super.key});

  @override
  State<BillingContent> createState() => _BillingContentState();
}

class _BillingContentState extends State<BillingContent> {
  List<BillingModel> sellers = [];
  BillingTotals? totals;
  bool isLoading = true;
  String? errorMessage;

    // --- 1. ESTADO PARA LOS FILTROS ---
  int selectedYear = DateTime.now().year;
  int selectedMonth = DateTime.now().month;

  @override
  void initState() {
    super.initState();
     _fetchBillingData(selectedYear, selectedMonth);
  }

 Future<void> _fetchBillingData(int year, int month) async {
    try {
      // AQUÍ TU ENDPOINT QUE DEVUELVE EL JSON CON DATO1, DATO2...
      final response = await http.get(
        // URL NUEVA (USAMOS LAS VARIABLES $year y $month):
        Uri.parse('https://app.grupo-solsumed.com/admin/index.php?action=gerenciales&c=GerenciaData&a=1&t=factura&ano=$year&mes=$month&vendedorId=all'),
      );

      if (response.statusCode == 200) {
        // Asumimos que la API devuelve el array directamente o dentro de 'data'
        // Si devuelve el array directo:
        List<dynamic> jsonList = jsonDecode(response.body);
        
        // Si devuelve envuelto en status/success:
        // final jsonResponse = jsonDecode(response.body);
        // List<dynamic> jsonList = jsonResponse['data'] ?? [];

        List<BillingModel> tempList = jsonList.map((e) => BillingModel.fromJson(e)).toList();

        // CALCULAR TOTALES
        double totalSales = 0;
        double totalReturns = 0;
        double totalCollections = 0;

        for (var item in tempList) {
          totalSales += item.sales;
          totalReturns += item.returns;
          totalCollections += item.collections;
        }

        setState(() {
          sellers = tempList;
          totals = BillingTotals(
            totalSales: totalSales,
            totalReturns: totalReturns,
            totalCollections: totalCollections,
          );
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

  
        // --- 3. ACTUALIZAR FILTROS ---
    void _updateFilters(int? newYear, int? newMonth) {
      setState(() {
        if (newYear != null) selectedYear = newYear;
        if (newMonth != null) selectedMonth = newMonth;
      });
      // REFRESCAR DATOS CON LOS NUEVOS FILTROS
      _fetchBillingData(selectedYear, selectedMonth);
    }


  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator(color: AppColors.primaryColor));
    }

    if (errorMessage != null) {
      return Center(child: Text("Error: $errorMessage"));
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. TÍTULO
          const Text('Reporte de Facturación', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.primaryColor)),
          const SizedBox(height: 20),

          // 2. AQUÍ ES DONDE AGREGAMOS EL FILTRO (Estaba faltando)
          _buildFilterRow(),

          const SizedBox(height: 20),

          // 3. WIDGETS DE TOTALES
          if (totals != null)
            Column(
              children: [
                _buildTotalCard('Total Facturado', totals!.totalSales, Icons.trending_up, Colors.blue),
                _buildTotalCard('Total Devoluciones', totals!.totalReturns, Icons.assignment_late, Colors.red),
                _buildTotalCard('Total Cobranzas', totals!.totalCollections, Icons.payments, Colors.green),
              ],
            ),

          const SizedBox(height: 30),

          // 4. LISTA DE VENDEDORES
          const Text('Desglose por Vendedor', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 15),
          
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: sellers.length,
            itemBuilder: (context, index) {
              return SellerPerformanceCard(seller: sellers[index]);
            },
          ),
          
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildTotalCard(String title, double value, IconData icon, Color color) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 20),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(icon, color: color),
              const SizedBox(width: 10),
              Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
            ],
          ),
          Text(
            "USD. ${value.toStringAsFixed(2)}",
            style: TextStyle(
              fontSize: 18, 
              fontWeight: FontWeight.bold, 
              color: color
            ),
          ),
        ],
      ),
    );
  }
    // --- 7. WIDGET DE FILTROS ---
  Widget _buildFilterRow() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardColor,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)],
        border: Border.all(color: AppColors.primaryColor.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Filtrar Período:", style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.grey)),
          const SizedBox(height: 15),
          
          Row(
            children: [
              // SELECTOR AÑO
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<int>(
                      isExpanded: true,
                      value: selectedYear,
                      // ELIMINADO: dropdownStyle: ...
                      items: List.generate(5, (index) => DateTime.now().year - index)
                          .map((year) => DropdownMenuItem<int>(
                                value: year,
                                child: Text(year.toString()),
                              ))
                          .toList(),
                      onChanged: (value) => _updateFilters(value, null),
                    ),
                  ),
                ),
              ),
              
              const SizedBox(width: 15),

              // SELECTOR MES
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<int>(
                      isExpanded: true,
                      value: selectedMonth,
                      // ELIMINADO: dropdownStyle: ...
                      items: List.generate(12, (index) => index + 1)
                          .map((month) => DropdownMenuItem<int>(
                                value: month,
                                child: Text(_getMonthName(month)),
                              ))
                          .toList(),
                      onChanged: (value) => _updateFilters(null, value),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _getMonthName(int month) {
    const months = ["Enero", "Febrero", "Marzo", "Abril", "Mayo", "Junio", "Julio", "Agosto", "Septiembre", "Octubre", "Noviembre", "Diciembre"];
    return months[month - 1];
  }

}