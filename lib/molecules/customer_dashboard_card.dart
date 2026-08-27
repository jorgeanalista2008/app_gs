import 'package:flutter/material.dart';
import '../core/app_colors.dart';

class CustomerDashboardCard extends StatelessWidget {
  final Map<String, dynamic> data;

  const CustomerDashboardCard({required this.data});

  String _formatCurrency(dynamic value) {
    if (value == null) return '\$0.00';
    final amount = value is num ? value : double.tryParse(value.toString()) ?? 0;
    return '\$${amount.toStringAsFixed(2)}';
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Análisis Financiero',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            _buildRow(
              'Saldos por vencer',
              _formatCurrency(data['saldos_por_vencer']),
              Colors.green,
            ),
            const SizedBox(height: 12),
            _buildRow(
              'Saldos vencidos',
              _formatCurrency(data['saldos_vencidos']),
              Colors.red,
            ),
            const Divider(height: 24),
            _buildRow(
              'Docs por vencer',
              '${data['docs_por_vencer'] ?? 0}',
              Colors.blue,
            ),
            const SizedBox(height: 12),
            _buildRow(
              'Docs vencidos',
              '${data['docs_vencidos'] ?? 0}',
              Colors.orange,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRow(String label, String value, Color color) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 14, color: AppColors.textPrimary),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: color.withValues(alpha: 0.3)),
          ),
          child: Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: color,
              fontSize: 13,
            ),
          ),
        ),
      ],
    );
  }
}
