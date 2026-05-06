import 'package:flutter/material.dart';
import '../models/dolar_model.dart';

// Ahora es StatelessWidget (recibe datos, no los busca)
class DolarIndicator extends StatelessWidget {
  final DolarModel dolar;
  final String title;
  final Color backgroundColor;

  const DolarIndicator({
    super.key,
    required this.dolar,
    required this.title,
    required this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded( // Usamos Expanded para que ambos ocupen el 50% de la fila
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 15),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: backgroundColor.withOpacity(0.3),
              blurRadius: 10,
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Título (BCV / USDT)
            Text(
              title,
              style: const TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 5),
            
            // Precio
            Text(
              'Bs. ${dolar.promedio.toStringAsFixed(2).replaceAll('.', ',')}',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
               // decoration: TextDecoration.underline, // Efecto ticker
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}