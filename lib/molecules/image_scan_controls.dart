// molecules/image_scan_controls.dart
import 'package:flutter/material.dart';
import '../core/app_colors.dart';

/// Molécula que muestra botones para escanear QR desde imagen
/// Permite seleccionar entre cámara y galería
class ImageScanControls extends StatelessWidget {
  final VoidCallback onCameraTap;
  final VoidCallback onGalleryTap;
  final bool isProcessing;

  const ImageScanControls({
    super.key,
    required this.onCameraTap,
    required this.onGalleryTap,
    this.isProcessing = false,
  });

  @override
  Widget build(BuildContext context) {
    if (isProcessing) {
      return _buildProcessingIndicator();
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            '¿No puedes escanear en tiempo real?',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildControlButton(
                icon: Icons.camera_alt,
                label: 'Tomar Foto',
                color: Colors.blue,
                onTap: onCameraTap,
              ),
              Container(
                height: 30,
                width: 1,
                color: Colors.white24,
              ),
              _buildControlButton(
                icon: Icons.photo_library,
                label: 'Galería',
                color: Colors.green,
                onTap: onGalleryTap,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.5)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProcessingIndicator() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(16),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: Colors.white,
            ),
          ),
          SizedBox(width: 12),
          Text(
            'Analizando imagen...',
            style: TextStyle(color: Colors.white),
          ),
        ],
      ),
    );
  }
}

/// Versión compacta del botón para la AppBar
class ImageScanButton extends StatelessWidget {
  final VoidCallback onTap;
  final bool isProcessing;

  const ImageScanButton({
    super.key,
    required this.onTap,
    this.isProcessing = false,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: isProcessing
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            )
          : const Icon(Icons.add_a_photo),
      tooltip: 'Escanear desde foto',
      onPressed: isProcessing ? null : onTap,
    );
  }
}

/// Diálogo simplificado para seleccionar origen de imagen
class ImageSourceDialog extends StatelessWidget {
  const ImageSourceDialog({super.key});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Row(
        children: [
          Icon(Icons.qr_code_scanner, color: AppColors.primaryColor),
          SizedBox(width: 10),
          Text('Escanear desde'),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildOption(
            context: context,
            icon: Icons.camera_alt,
            title: 'Tomar Foto',
            subtitle: 'Captura el código QR con la cámara',
            color: Colors.blue,
            onTap: () => Navigator.pop(context, ImageSource.camera),
          ),
          const SizedBox(height: 12),
          _buildOption(
            context: context,
            icon: Icons.photo_library,
            title: 'Seleccionar de Galería',
            subtitle: 'Usa una foto ya guardada',
            color: Colors.green,
            onTap: () => Navigator.pop(context, ImageSource.gallery),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
      ],
    );
  }

  Widget _buildOption({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: color),
          ],
        ),
      ),
    );
  }
}

enum ImageSource { camera, gallery }
