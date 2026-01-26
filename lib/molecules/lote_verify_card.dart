import 'package:flutter/material.dart';
import '../core/app_colors.dart';
import '../models/lote_model.dart';

class LoteVerifyCard extends StatelessWidget {
  final LoteModel lote;
  final VoidCallback onVerify;
  final bool isVerified;

  const LoteVerifyCard({
    super.key,
    required this.lote,
    required this.onVerify,
    this.isVerified = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isVerified ? Colors.green.shade50 : AppColors.cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isVerified ? Colors.green : AppColors.primaryColor,
          width: 2,
        ),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Estado y Icono
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: isVerified ? Colors.green : Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  children: [
                    Icon(
                      isVerified ? Icons.check_circle : Icons.pending,
                      color: isVerified ? Colors.white : Colors.grey,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      isVerified ? "VERIFICADO" : "POR VERIFICAR",
                      style: TextStyle(
                        color: isVerified ? Colors.white : Colors.black54,
                        fontWeight: FontWeight.bold,
                      fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              if (isVerified)
                const Icon(Icons.verified, color: Colors.green, size: 30),
            ],
          ),
          const SizedBox(height: 20),

          // Contenido
          Text("Cliente", style: TextStyle(fontSize: 12, color: Colors.grey[600])),
          Text(lote.title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 15),
          Row(
            children: [
              const Icon(Icons.location_on, color: AppColors.primaryColor),
              const SizedBox(width: 5),
              Expanded(child: Text(lote.address, style: const TextStyle(fontSize: 14))),
            ],
          ),
          const SizedBox(height: 15),
          Row(
            children: [
              const Icon(Icons.attach_money, color: Colors.green),
              const SizedBox(width: 5),
              Text("Monto: ${lote.amount}", style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ],
          ),

          const SizedBox(height: 30),

          // Botón de Acción
          if (!isVerified)
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                onPressed: onVerify,
                icon: const Icon(Icons.verified_user),
                label: const Text("VERIFICAR LOTE"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            )
          else
            Center(
              child: Text(
                "Este lote ha sido verificado exitosamente",
                style: TextStyle(color: Colors.green.shade700, fontWeight: FontWeight.bold),
              ),
            ),
        ],
      ),
    );
  }
}