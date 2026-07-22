import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../core/app_colors.dart';

class PhotoCaptureWidget extends StatefulWidget {
  final String label;
  final Function(File? file, String? base64String)? onPhotoTaken;
  final File? initialPhoto;

  const PhotoCaptureWidget({
    super.key,
    this.label = 'Tomar foto',
    this.onPhotoTaken,
    this.initialPhoto,
  });

  @override
  State<PhotoCaptureWidget> createState() => _PhotoCaptureWidgetState();
}

class _PhotoCaptureWidgetState extends State<PhotoCaptureWidget> {
  final ImagePicker _picker = ImagePicker();
  File? _photo;

  @override
  void initState() {
    super.initState();
    _photo = widget.initialPhoto;
  }

  Future<void> _tomarFoto() async {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('La captura de imágenes está deshabilitada temporalmente.'),
          backgroundColor: Colors.orange,
        ),
      );
    }
    return;
    /* Deshabilitado temporalmente:
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 80,
        maxWidth: 1024,
        maxHeight: 1024,
      );

      if (image != null) {
        final bytes = await image.readAsBytes();
        final base64String = base64Encode(bytes);
        final file = File(image.path);
        setState(() => _photo = file);
        widget.onPhotoTaken?.call(file, base64String);
      }
    } catch (e) {
      print('❌ Error al tomar foto: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al tomar foto: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
    */
  }

  Future<void> _seleccionarDeGaleria() async {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('La selección de imágenes desde la galería está deshabilitada temporalmente.'),
          backgroundColor: Colors.orange,
        ),
      );
    }
    return;
    /* Deshabilitado temporalmente:
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
        maxWidth: 1024,
        maxHeight: 1024,
      );

      if (image != null) {
        final bytes = await image.readAsBytes();
        final base64String = base64Encode(bytes);
        final file = File(image.path);
        setState(() => _photo = file);
        widget.onPhotoTaken?.call(file, base64String);
      }
    } catch (e) {
      print('❌ Error al seleccionar foto: $e');
    }
    */
  }

  void _eliminarFoto() {
    setState(() => _photo = null);
    widget.onPhotoTaken?.call(null, null);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[300]!),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          // Área de la foto
          GestureDetector(
            onTap: _photo == null ? _mostrarOpciones : null,
            child: Container(
              height: 160,
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: const BorderRadius.vertical(top: Radius.circular(13)),
              ),
              child: _photo != null
                  ? ClipRRect(
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(13)),
                      child: Stack(
                        children: [
                          // Imagen de fondo
                          Positioned.fill(
                            child: kIsWeb
                                ? Image.network(
                                    _photo!.path,
                                    fit: BoxFit.cover,
                                  )
                                : Image.file(
                                    _photo!,
                                    fit: BoxFit.cover,
                                  ),
                          ),
                          // Botón eliminar
                          Positioned(
                            top: 8,
                            right: 8,
                            child: GestureDetector(
                              onTap: _eliminarFoto,
                              child: Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.6),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.close, color: Colors.white, size: 18),
                              ),
                            ),
                          ),
                          // Botón cambiar
                          Positioned(
                            bottom: 8,
                            right: 8,
                            child: GestureDetector(
                              onTap: _mostrarOpciones,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.6),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.camera_alt, color: Colors.white, size: 14),
                                    SizedBox(width: 4),
                                    Text('Cambiar', style: TextStyle(color: Colors.white, fontSize: 12)),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    )
                  : Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.camera_alt, size: 40, color: Colors.grey[400]),
                        const SizedBox(height: 8),
                        Text(widget.label, style: TextStyle(color: Colors.grey[500], fontSize: 14)),
                        const SizedBox(height: 4),
                        Text('Toca para capturar', style: TextStyle(color: Colors.grey[400], fontSize: 11)),
                      ],
                    ),
            ),
          ),

        
          // Botones de acción
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: Colors.grey[200]!)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                Flexible(
                  child: _buildActionButton(Icons.camera_alt, 'Cámara', _tomarFoto),
                ),
                const SizedBox(width: 2),
                Flexible(
                  child: _buildActionButton(Icons.photo_library, 'Galería', _seleccionarDeGaleria),
                ),
                if (_photo != null) ...[
                  const SizedBox(width: 2),
                  Flexible(
                    child: _buildActionButton(Icons.delete, 'Eliminar', _eliminarFoto, color: Colors.red),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

    Widget _buildActionButton(IconData icon, String label, VoidCallback onTap, {Color? color}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: color ?? AppColors.primaryColor),
            const SizedBox(height: 2),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                label,
                style: TextStyle(fontSize: 9, color: color ?? AppColors.primaryColor),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _mostrarOpciones() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Seleccionar imagen', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 20),
                ListTile(
                  leading: const Icon(Icons.camera_alt, color: AppColors.primaryColor),
                  title: const Text('Tomar foto'),
                  onTap: () {
                    Navigator.pop(context);
                    _tomarFoto();
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.photo_library, color: AppColors.primaryColor),
                  title: const Text('Seleccionar de galería'),
                  onTap: () {
                    Navigator.pop(context);
                    _seleccionarDeGaleria();
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}