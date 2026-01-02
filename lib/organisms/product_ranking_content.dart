import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../core/app_colors.dart';
import '../models/product_model.dart';
import '../molecules/product_ranking_item.dart';

class ProductRankingContent extends StatefulWidget {
  const ProductRankingContent({super.key});

  @override
  State<ProductRankingContent> createState() => _ProductRankingContentState();
}

class _ProductRankingContentState extends State<ProductRankingContent> {
  List<ProductModel> products = [];
  ProductTotals? totals;
  bool isLoading = true;

  // --- 1. ESTADO PARA LOS FILTROS ---
  int selectedYear = DateTime.now().year;
  int selectedMonth = DateTime.now().month;

  @override
  void initState() {
    super.initState();
    _fetchProducts(selectedYear, selectedMonth);
  }

  // --- 2. FUNCIÓN ACTUALIZADA (RECIBE AÑO Y MES) ---
  Future<void> _fetchProducts(int year, int month) async {
    setState(() => isLoading = true);
    try {
      // URL DINÁMICA: Usamos $year y $month en la URL
      final response = await http.get(
        Uri.parse('https://app.grupo-solsumed.com/admin/index.php?action=gerenciales&c=GerenciaData&a=3&t=factura&ano=$year&mes=$month&vendedorId=all'),
      );

      if (response.statusCode == 200) {
        List<dynamic> jsonList = jsonDecode(response.body);
        List<ProductModel> tempProducts = jsonList.map((e) => ProductModel.fromJson(e)).toList();

        // CALCULAR TOTALES
        double totalValue = 0;
        for(var p in tempProducts){
          totalValue += p.value;
        }

        setState(() {
          products = tempProducts;
          totals = ProductTotals(
            totalValue: totalValue,
            totalProducts: tempProducts.length,
            topProduct: tempProducts.isNotEmpty ? tempProducts[0].name : "N/A",
          );
          isLoading = false;
        });
      }
    } catch (e) {
      setState(() => isLoading = false);
    }
  }

  // --- 3. ACTUALIZAR FILTROS ---
  void _updateFilters(int? newYear, int? newMonth) {
    setState(() {
      if (newYear != null) selectedYear = newYear!;
      if (newMonth != null) selectedMonth = newMonth!;
    });
    // REFRESCAR DATOS CON LOS NUEVOS FILTROS
    _fetchProducts(selectedYear, selectedMonth);
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator(color: AppColors.primaryColor));
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Ranking de Productos', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.primaryColor)),
          const SizedBox(height: 20),

          // --- 4. UI DE FILTROS (DROPDOWNS) ---
          _buildFilterRow(),

          const SizedBox(height: 20),

          // --- 5. WIDGETS DE RESUMEN ---
          if (totals != null)
            Column(
              children: [
                _buildTotalCard('Total Valor', totals!.totalValue.toStringAsFixed(2).replaceAll('.', ','), Icons.inventory_2, Colors.orange),
                _buildTotalCard('Total Items', '${totals!.totalProducts}', Icons.list, Colors.blue),
                const SizedBox(height: 15),
                _buildHighlightCard('Producto Top', totals!.topProduct),
              ],
            ),
          
          const SizedBox(height: 30),

          // --- 6. LISTA DE RANKING ---
          const Text('Desglose Completo', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 15),
          
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: products.length,
            itemBuilder: (context, index) {
              return ProductRankingItem(index: index, product: products[index]);
            },
          ),
          
          const SizedBox(height: 40),
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

  // Auxiliar para nombre del mes (1-12 -> Enero, Feb...)
  String _getMonthName(int month) {
    const months = ["Enero", "Febrero", "Marzo", "Abril", "Mayo", "Junio", "Julio", "Agosto", "Septiembre", "Octubre", "Noviembre", "Diciembre"];
    return months[month - 1];
  }

  // WIDGETS DE TARJETAS (Que ya tenías, los dejo igual)
  Widget _buildTotalCard(String title, String value, IconData icon, Color color) {
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
            value,
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color),
          ),
        ],
      ),
    );
  }

  Widget _buildHighlightCard(String title, String value) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.primaryColor,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [BoxShadow(color: AppColors.primaryColor.withOpacity(0.3), blurRadius: 10)],
      ),
      child: Row(
        children: [
          const Icon(Icons.emoji_events, color: Colors.white, size: 30),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(color: Colors.white70, fontSize: 12)),
                Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
              ],
            ),
          )
        ],
      ),
    );
  }
}