// molecules/image_scan_fab.dart - VERSIÓN CORREGIDA
import 'package:flutter/material.dart';
import '../core/app_colors.dart';

/// Botón flotante que despliega un menú hacia arriba
/// con opciones para escanear QR desde foto
class ImageScanFab extends StatefulWidget {
  final Future<void> Function() onCameraTap;
  final Future<void> Function() onGalleryTap;
  final bool isProcessing;

  const ImageScanFab({
    super.key,
    required this.onCameraTap,
    required this.onGalleryTap,
    this.isProcessing = false,
  });

  @override
  State<ImageScanFab> createState() => _ImageScanFabState();
}

class _ImageScanFabState extends State<ImageScanFab>
    with SingleTickerProviderStateMixin {
  bool _isExpanded = false;
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _animation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _toggle() {
    setState(() {
      _isExpanded = !_isExpanded;
      if (_isExpanded) {
        _controller.forward();
      } else {
        _controller.reverse();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        // Menú desplegable (ARRIBA del botón)
        AnimatedSize(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutCubic,
          child: _isExpanded ? _buildMenu() : const SizedBox.shrink(),
        ),

        const SizedBox(height: 12),

        // Botón principal
        _buildMainButton(),
      ],
    );
  }

  Widget _buildMenu() {
    return FadeTransition(
      opacity: _animation,
      child: Container(
        width: 260,
        margin: const EdgeInsets.only(bottom: 4),
        decoration: BoxDecoration(
          color: Colors.grey[900],
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.5),
              blurRadius: 20,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
              child: Row(
                children: [
                  Icon(
                    Icons.qr_code_scanner,
                    color: AppColors.primaryColor,
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  const Text(
                    'Escanear desde foto',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),

            const Divider(color: Colors.white24, height: 1),

            // Opción: Tomar Foto
            _buildMenuOption(
              icon: Icons.camera_alt,
              label: 'Tomar Foto',
              subtitle: 'Capturar QR con la cámara',
              color: Colors.blue,
              onTap: () {
                _toggle();
                widget.onCameraTap();
              },
            ),

            const Divider(color: Colors.white12, height: 1, indent: 56),

            // Opción: Desde Galería
            _buildMenuOption(
              icon: Icons.photo_library,
              label: 'Desde Galería',
              subtitle: 'Seleccionar foto existente',
              color: Colors.green,
              onTap: () {
                _toggle();
                widget.onGalleryTap();
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuOption({
    required IconData icon,
    required String label,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(20),
          bottomRight: Radius.circular(20),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: Colors.grey[400],
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right,
                color: Colors.grey[600],
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMainButton() {
    return GestureDetector(
      onTap: widget.isProcessing ? null : _toggle,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: _isExpanded ? AppColors.primaryColor : Colors.grey[900],
          borderRadius: BorderRadius.circular(30),
          boxShadow: [
            BoxShadow(
              color: (_isExpanded ? AppColors.primaryColor : Colors.black)
                  .withValues(alpha: 0.4),
              blurRadius: 12,
              spreadRadius: 1,
            ),
          ],
        ),
        child: widget.isProcessing
            ? _buildProcessingContent()
            : _buildButtonContent(),
      ),
    );
  }

  Widget _buildButtonContent() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          child: Icon(
            _isExpanded ? Icons.close : Icons.add_a_photo,
            color: Colors.white,
            size: 22,
            key: ValueKey(_isExpanded),
          ),
        ),
        const SizedBox(width: 10),
        Text(
          _isExpanded ? 'Cerrar' : 'Escanear foto',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(width: 4),
        AnimatedRotation(
          turns: _isExpanded ? 0.5 : 0,
          duration: const Duration(milliseconds: 200),
          child: Icon(
            Icons.keyboard_arrow_up,
            color: Colors.white70,
            size: 20,
          ),
        ),
      ],
    );
  }

  Widget _buildProcessingContent() {
    return const Row(
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
          'Analizando...',
          style: TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}