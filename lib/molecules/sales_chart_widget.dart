import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../core/app_colors.dart';
import '../models/dashboard_model.dart';

class SalesChartWidget extends StatelessWidget {
  final List<ChartDataPoint> data; // <--- RECIBE DATOS

  const SalesChartWidget({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    // Preparamos los grupos de barras dinámicamente
    List<BarChartGroupData> barGroups = data.map((point) {
      return BarChartGroupData(
        x: point.mes - 1, // Eje X (0 a 5)
        barRods: [
          BarChartRodData(
            toY: point.valor,
            color: AppColors.primaryColor,
            width: 16,
            borderRadius: BorderRadius.circular(4),
          ),
        ],
      );
    }).toList();

    return AspectRatio(
      aspectRatio: 1.7,
      child: BarChart(
        BarChartData(
          alignment: BarChartAlignment.spaceAround,
          maxY: data.isEmpty ? 1000 : data.map((e) => e.valor).reduce((a, b) => a > b ? a : b) * 1.2, // Escala dinámica
          minY: 0,
          barTouchData: BarTouchData(enabled: true),
          titlesData: FlTitlesData(
            leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 30, getTitlesWidget: (val, meta) {
              // Formato simple para eje Y
              return Text(val.toInt() > 999 ? "${(val/1000).toStringAsFixed(0)}k" : val.toInt().toString(), style: const TextStyle(fontSize: 10, color: Colors.grey));
            })),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) {
                  const style = TextStyle(color: Colors.grey, fontWeight: FontWeight.bold, fontSize: 10);
                  String text;
                  switch (value.toInt()) {
                    case 0: text = 'ENE'; break;
                    case 1: text = 'FEB'; break;
                    case 2: text = 'MAR'; break;
                    case 3: text = 'ABR'; break;
                    case 4: text = 'MAY'; break;
                    case 5: text = 'JUN'; break;
                    case 6: text = 'JUL'; break;
                    case 7: text = 'AGO'; break;
                    case 8: text = 'SEP'; break;
                    case 9: text = 'OCT'; break;
                    case 10: text = 'NOV'; break;
                    case 11: text = 'DIC'; break;
                    default: text = '';
                  }
                  return Text(text, style: style);
                },
              ),
            ),
            topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          gridData: FlGridData(show: true, drawVerticalLine: false),
          borderData: FlBorderData(show: false),
          barGroups: barGroups, // <--- INYECTAMOS DATOS REALES
        ),
      ),
    );
  }
}