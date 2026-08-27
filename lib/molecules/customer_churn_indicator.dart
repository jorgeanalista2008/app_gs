import 'package:flutter/material.dart';
import '../core/app_colors.dart';

class CustomerChurnIndicator extends StatelessWidget {
  final int? churnScore;
  final String? churnRisk;

  const CustomerChurnIndicator({
    this.churnScore,
    this.churnRisk,
  });

  Color _getColorByRisk(String? risk) {
    switch (risk?.toLowerCase()) {
      case 'bajo':
        return Colors.green;
      case 'medio':
        return Colors.orange;
      case 'alto':
        return Colors.red;
      case 'crítico':
        return const Color(0xFFB71C1C);
      default:
        return Colors.grey;
    }
  }

  IconData _getIconByRisk(String? risk) {
    switch (risk?.toLowerCase()) {
      case 'bajo':
        return Icons.trending_up;
      case 'medio':
        return Icons.trending_flat;
      case 'alto':
      case 'crítico':
        return Icons.trending_down;
      default:
        return Icons.help;
    }
  }

  @override
  Widget build(BuildContext context) {
    final score = churnScore ?? 0;
    final risk = churnRisk ?? 'Desconocido';
    final color = _getColorByRisk(risk);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: color.withValues(alpha: 0.02),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  _getIconByRisk(risk),
                  color: color,
                  size: 28,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Riesgo de Churn',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${risk.toUpperCase()} (Score: $score/100)',
                        style: TextStyle(
                          fontSize: 13,
                          color: color,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: score / 100,
                minHeight: 8,
                backgroundColor: Colors.grey[300],
                valueColor: AlwaysStoppedAnimation<Color>(color),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _getDescriptionByScore(score),
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[700],
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getDescriptionByScore(int score) {
    if (score < 25) return 'Cliente muy seguro, mantener relación';
    if (score < 50) return 'Cliente estable, sin alertas inmediatas';
    if (score < 75) return 'Requiere atención, posible contacto';
    return 'Crítico, acción inmediata recomendada';
  }
}
