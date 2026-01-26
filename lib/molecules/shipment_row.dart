import 'package:flutter/material.dart';
import '../core/app_colors.dart';
import '../models/shipment_model.dart';

class ShipmentRow extends StatelessWidget {
  final ShipmentModel shipment;

  const ShipmentRow({
    super.key,
    required this.shipment,
  });

  MaterialColor _getColorForState(String estado) {
    switch (estado.toLowerCase()) {
      case 'pendiente':
        return Colors.orange; // Naranja para pendiente
      case 'en proceso':
        return Colors.blue;    // Azul para en proceso
      case 'entregado':
        return Colors.green;   // Verde para entregado
      case 'cancelado':
        return Colors.grey;    // Gris para cancelado
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 15),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 5)],
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // 1. ID / Embarco (Agrupados visualmente)
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(shipment.embarco, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                Text(shipment.id, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
              ],
            ),
          ),
          
          // 2. Cliente
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(shipment.cliente, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(shipment.fecha, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
              ],
            ),
          ),
          
          // 3. Estado
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: _getColorForState(shipment.estado),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              shipment.estado, 
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}