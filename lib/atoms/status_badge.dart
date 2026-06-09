import 'package:flutter/material.dart';
import '../core/app_colors.dart';

class StatusBadge extends StatelessWidget {
  final String status;
  final bool small;
  
  const StatusBadge({
    super.key,
    required this.status,
    this.small = false,
  });

  @override
  Widget build(BuildContext context) {
    final statusColor = _getStatusColor(status);
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: small ? 10 : 14,
        vertical: small ? 4 : 6,
      ),
      decoration: BoxDecoration(
        color: statusColor.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(30), // Cápsula elegante
        border: Border.all(
          color: statusColor.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: Text(
        status.toUpperCase(),
        style: TextStyle(
          color: statusColor,
          fontSize: small ? 9 : 11,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'entregado':
      case 'verificado':
      case 'activo':
      case 'completado':
        return AppColors.successColor;
      case 'pendiente':
        return AppColors.warningColor;
      case 'rechazado':
      case 'inactivo':
        return AppColors.errorColor;
      case 'en camino':
        return AppColors.secondaryColor;
      default:
        return AppColors.textSecondary;
    }
  }
}