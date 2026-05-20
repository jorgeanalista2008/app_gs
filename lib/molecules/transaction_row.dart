import 'package:flutter/material.dart';
import '../core/app_colors.dart';
import '../atoms/status_badge.dart';

class TransactionRow extends StatelessWidget {
  final String id;
  final String client;
  final String amount;
  final String status;
  final bool isPositive;

  const TransactionRow({
    super.key,
    required this.id,
    required this.client,
    required this.amount,
    required this.status,
    this.isPositive = true,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.cardColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 5)],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: AppColors.primaryColor.withOpacity(0.1),
                child: Text(client[0], style: const TextStyle(color: AppColors.primaryColor, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(client, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  Text("Pedido #$id", style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                ],
              ),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(amount, style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
              const SizedBox(height: 4),
              StatusBadge(
                status: status,
                small: true,
              ),
            ],
          ),
        ],
      ),
    );
  }
}