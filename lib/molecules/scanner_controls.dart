// molecules/scanner_controls.dart
import 'package:flutter/material.dart';

class ScannerControls extends StatelessWidget {
  final bool isFlashOn;
  final VoidCallback onToggleFlash;
 // final VoidCallback onToggleCamera;
  
  const ScannerControls({
    super.key,
    required this.isFlashOn,
    required this.onToggleFlash,
    //required this.onToggleCamera,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildControlButton(
          icon: isFlashOn ? Icons.flash_on : Icons.flash_off,
          label: isFlashOn ? 'Flash ON' : 'Flash OFF',
          onPressed: onToggleFlash,
        ),
        const SizedBox(width: 20),
       /* _buildControlButton(
          icon: Icons.cameraswitch,
          label: 'Cambiar Cámara',
          onPressed: onToggleCamera,
        ),*/
      ],
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
  }) {
    return Column(
      children: [
        IconButton(
          icon: Icon(icon, size: 28),
          onPressed: onPressed,
          style: IconButton.styleFrom(
            backgroundColor: Colors.white.withValues(alpha: 0.9),
            padding: const EdgeInsets.all(12),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 10,
          ),
        ),
      ],
    );
  }
}