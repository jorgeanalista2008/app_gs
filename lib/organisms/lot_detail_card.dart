// lib/features/scanner/organisms/lot_detail_card.dart
import 'package:flutter/material.dart';
import '../models/lot_model.dart';
import '../core/app_colors.dart';
import '../atoms/status_badge.dart';
import '../molecules/lot_info_row.dart';

class LotDetailCard extends StatelessWidget {
  final LotModel lot;
  final Function()? onVerify;
  final Function()? onReject;
  final bool isLoading;

  const LotDetailCard({
    super.key,
    required this.lot,
    this.onVerify,
    this.onReject,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.all(16),
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Encabezado con ID y estado
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Lote #${lot.loteId}',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primaryColor,
                  ),
                ),
                StatusBadge(status: lot.estado),
              ],
            ),
            
            const SizedBox(height: 16),
            
            // Información del cliente
            LotInfoRow(
              icon: Icons.person,
              label: 'Cliente',
              value: lot.cliente,
            ),
            
            LotInfoRow(
              icon: Icons.location_on,
              label: 'Dirección',
              value: lot.direccion,
            ),
            
            LotInfoRow(
              icon: Icons.phone,
              label: 'Teléfono',
              value: lot.telefono,
            ),
            
            const Divider(height: 24),
            
            // Información del producto
            LotInfoRow(
              icon: Icons.inventory,
              label: 'Producto',
              value: lot.producto,
            ),
            
            LotInfoRow(
              icon: Icons.numbers,
              label: 'Cantidad',
              value: '${lot.cantidad} unidades',
            ),
            
            if (lot.fechaEntrega != null) ...[
              LotInfoRow(
                icon: Icons.calendar_today,
                label: 'Fecha Entrega',
                value: '${lot.fechaEntrega}',
              ),
            ],
            
            if (lot.observaciones != null && lot.observaciones!.isNotEmpty) ...[
              const SizedBox(height: 16),
              const Text(
                'Observaciones:',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                lot.observaciones!,
                style: const TextStyle(color: Colors.grey),
              ),
            ],
            
            // Botones de acción
            if (onVerify != null || onReject != null) ...[
              const Divider(height: 32),
              _buildActionButtons(context),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons(BuildContext context) {
    return Row(
      children: [
        if (onReject != null)
          Expanded(
            child: OutlinedButton.icon(
              onPressed: isLoading ? null : onReject,
              icon: const Icon(Icons.close, color: Colors.red),
              label: const Text(
                'Rechazar',
                style: TextStyle(color: Colors.red),
              ),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                side: const BorderSide(color: Colors.red),
              ),
            ),
          ),
        
        if (onReject != null && onVerify != null)
          const SizedBox(width: 16),
        
        if (onVerify != null)
          Expanded(
            child: ElevatedButton.icon(
              onPressed: isLoading ? null : onVerify,
              icon: const Icon(Icons.check, color: Colors.white),
              label: isLoading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('Verificar Entrega'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryColor,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ),
      ],
    );
  }
}