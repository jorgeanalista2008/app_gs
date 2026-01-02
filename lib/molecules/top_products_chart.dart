import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../core/app_colors.dart';
import '../models/product_model.dart';

class TopProductsChart extends StatelessWidget {
  final List<ProductModel> products;

  const TopProductsChart({
    super.key,
    required this.products,
  });

  @override
  Widget build(BuildContext context) {
    // Tomamos solo los primeros 5 para la gráfica
    final top5 = products.take(5).toList();

    // Calculamos el valor máximo para la escala
    int maxY = top5.isEmpty ? 100 : top5.map((p) => p.units).reduce((a, b) => a > b ? a : b);
    maxY = (maxY * 1.2).toInt(); // Un poco de espacio arriba

    return AspectRatio(
      aspectRatio: 1.8,
      child: BarChart(
        BarChartData(
          alignment: BarChartAlignment.spaceAround,
          maxY: maxY.toDouble(),
          minY: 0,
          barTouchData: BarTouchData(
            enabled: true,
            touchTooltipData: BarTouchTooltipData(
              getTooltipColor: (group) => AppColors.primaryColor,
              getTooltipItem: (group, groupIndex, rod, rodIndex) {
                // Aseguramos que no exceda el índice
                if (groupIndex >= top5.length) return null;
                
                final productName = top5[groupIndex].name;
                return BarTooltipItem(
                  '$productName\n${rod.toY.toInt()} Unidades',
                  const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                );
              },
            ),
          ),
          titlesData: FlTitlesData(
            show: true,
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 30,
                getTitlesWidget: (value, meta) => Text(value.toInt().toString(), style: const TextStyle(fontSize: 10, color: Colors.grey)),
              ),
            ),
            topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) => Text("#${(value + 1).toInt()}", style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primaryColor)),
              ),
            ),
          ),
          gridData: FlGridData(show: true, drawVerticalLine: false),
          borderData: FlBorderData(show: false),
          
          // --- AQUÍ ESTÁ EL CORRECCIÓN ---
          // Debes envolver esto en List.generate para que 'index' exista
          barGroups: List.generate(
            top5.length,
            (index) => BarChartGroupData(
              x: index,// index existe aquí
              barRods: [
                BarChartRodData(
                  toY: top5[index].units.toDouble(),
                  color: AppColors.primaryColor,
                  width: 16,
                  borderRadius: BorderRadius.circular(4),
                  gradient: LinearGradient(
                    colors: [AppColors.primaryColor, AppColors.secondaryColor],
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}