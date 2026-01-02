import 'package:flutter/material.dart';
import '../core/app_colors.dart';
import '../models/billing_model.dart';

class SellerPerformanceCard extends StatelessWidget {
  final BillingModel seller;

  const SellerPerformanceCard({
    super.key,
    required this.seller,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 15),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8)],
        border: Border(left: BorderSide(color: AppColors.primaryColor, width: 4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Nombre del Vendedor
          Text(
            seller.name.toUpperCase(),
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 12),

          // Fila de Métricas
          Row(
            children: [
              Expanded(
                child: _buildMetricItem(
                  'Facturación', 
                  seller.sales.toStringAsFixed(2), 
                  Colors.blue
                ),
              ),
              Expanded(
                child: _buildMetricItem(
                  'Devoluciones', 
                  seller.returns.toStringAsFixed(2), 
                  Colors.red,
                  isNegative: true,
                ),
              ),
              Expanded(
                child: _buildMetricItem(
                  'Cobranzas', 
                  seller.collections.toStringAsFixed(2), 
                  Colors.greenAccent,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetricItem(String label, String value, Color color, {bool isNegative = false}) {
    return Column(
      children: [
        Text(label, style: TextStyle(fontSize: 11, color: Colors.grey[600])),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: color,
            decoration: isNegative ? TextDecoration.lineThrough : null,
          ),
        ),
      ],
    );
  }
}