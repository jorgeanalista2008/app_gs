import 'package:flutter/material.dart';
import '../core/app_colors.dart';
import '../models/product_model.dart';

class ProductRankingItem extends StatelessWidget {
  final int index;
  final ProductModel product;

  const ProductRankingItem({
    super.key,
    required this.index,
    required this.product,
  });

  @override
  Widget build(BuildContext context) {
    Color rankColor = Colors.grey;
    
    // Colores especiales para el Top 3
    if (index == 0) rankColor = Colors.amber; // Oro
    if (index == 1) rankColor = Colors.grey.shade400; // Plata
    if (index == 2) rankColor = Colors.brown.shade400; // Bronce

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.cardColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 6)],
        border: index < 3 ? Border.all(color: rankColor.withOpacity(0.5)) : null,
      ),
      child: Row(
        children: [
          // Ranking Number
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: rankColor.withOpacity(0.1),
              shape: BoxShape.circle,
              border: Border.all(color: rankColor),
            ),
            child: Center(
              child: Text(
                "${index + 1}",
                style: TextStyle(
                  fontWeight: FontWeight.bold, 
                  color: rankColor,
                  fontSize: 16
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),

          // Producto y Proveedor
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  product.name,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.primaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    product.provider,
                    style: const TextStyle(fontSize: 11, color: AppColors.primaryColor, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),

          // Valor
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                product.formattedValue,
                style: const TextStyle(
                  fontSize: 16, 
                  fontWeight: FontWeight.bold,
                  color: Colors.green
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}