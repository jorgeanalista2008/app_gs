// atoms/scanner_overlay.dart
import 'package:flutter/material.dart';

class ScannerOverlay extends StatelessWidget {
  final Color color;
  final double size;
  
  const ScannerOverlay({
    super.key,
    this.color = Colors.green,
    this.size = 250,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(size, size),
      painter: _ScannerOverlayPainter(color: color),
    );
  }
}

class _ScannerOverlayPainter extends CustomPainter {
  final Color color;
  
  const _ScannerOverlayPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 4
      ..style = PaintingStyle.stroke;

    final cornerLength = 30.0;
    
    // Dibujar esquinas
    canvas.drawLine(Offset.zero, Offset(cornerLength, 0), paint);
    canvas.drawLine(Offset.zero, Offset(0, cornerLength), paint);
    // ... resto de las esquinas
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}