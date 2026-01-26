// lib/features/scanner/atoms/status_badge.dart
import 'package:flutter/material.dart';
import '../../../core/app_colors.dart';

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
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: small ? 8 : 12,
        vertical: small ? 4 : 6,
      ),
      decoration: BoxDecoration(
        color: _getStatusColor(status),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        status.toUpperCase(),
        style: TextStyle(
          color: Colors.white,
          fontSize: small ? 10 : 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'entregado': return Colors.green;
      case 'pendiente': return Colors.orange;
      case 'rechazado': return Colors.red;
      case 'en camino': return Colors.blue;
      case 'verificado': return Colors.green;
      default: return Colors.grey;
    }
  }
}