import 'package:flutter/material.dart';
import '../core/app_colors.dart';

class CustomerStatsCard extends StatelessWidget {
  final Map<String, dynamic> data;

  const CustomerStatsCard({required this.data});

  String _formatCurrency(dynamic value) {
    if (value == null) return '\$0.00';
    final amount = value is num ? value : double.tryParse(value.toString()) ?? 0;
    return '\$${amount.toStringAsFixed(2)}';
  }

  String _formatDate(dynamic value) {
    if (value == null) return 'N/A';
    return value.toString().split('T').first;
  }

  @override
  Widget build(BuildContext context) {
    final numFacturas = data['num_facturas'] ?? 0;
    final diasSinComprar = data['dias_sin_comprar'] ?? 0;
    final totalUsd = data['total_neto_usd'] ?? 0.0;

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
              'Estadísticas de Compra',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStat('Facturas', '$numFacturas'),
                _buildStat('Total USD', _formatCurrency(totalUsd)),
                _buildStat('Días sin comprar', '$diasSinComprar'),
              ],
            ),
            const Divider(height: 32),
            _buildDetailRow(
              'Primera compra',
              _formatDate(data['primera_compra']),
            ),
            const SizedBox(height: 8),
            _buildDetailRow(
              'Última compra',
              _formatDate(data['ultima_compra']),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStat(String label, String value) {
    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: Colors.grey,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: AppColors.primaryColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppColors.primaryColor,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 13, color: Colors.grey),
        ),
        Text(
          value,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
      ],
    );
  }
}
