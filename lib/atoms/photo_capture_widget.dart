import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show PlatformException;
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import '../core/app_colors.dart';
import '../services/location_tracking_service.dart';

/// Payload devuelto tras capturar/seleccionar una foto.
///
/// [position] y [capturedAt] describen dónde y cuándo se tomó la foto —
/// crítico para que backend guarde la ubicación real del evento, no la de
/// la subida. `position` es null si el GPS no respondió a tiempo o el
/// permiso está denegado.
class PhotoCapture {
  final File? file;
  final String? base64;
  final Position? position;
  final DateTime capturedAt;
  final String? ubicacionLocalId;

  const PhotoCapture({
    required this.file,
    required this.base64,
    required this.position,
    required this.capturedAt,
    required this.ubicacionLocalId,
  });
}

class PhotoCaptureWidget extends StatefulWidget {
  final String label;
  final Function(File? file, String? base64String)? onPhotoTaken;
  final Function(PhotoCapture capture)? onPhotoTakenWithLocation;
  final File? initialPhoto;

  /// Si se pasa, cada foto capturada registra una ubicación asociada a
  /// esta visita (`location_source='foto'`).
  final String? visitId;

  const PhotoCaptureWidget({
    super.key,
    this.label = 'Tomar foto',
    this.onPhotoTaken,
    this.onPhotoTakenWithLocation,
    this.initialPhoto,
    this.visitId,
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
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 80,
        maxWidth: 1024,
        maxHeight: 1024,
      );

      if (image != null) {
        final capturedAt = DateTime.now();
        final bytes = await image.readAsBytes();
        final base64String = base64Encode(bytes);
        final file = File(image.path);
        setState(() => _photo = file);
        // Capturar ubicación en paralelo — no bloquear la UI si tarda.
        final pos = await _capturarUbicacion();
        String? ubicacionId;
        if (pos != null) {
          ubicacionId = await LocationTrackingService.instance
              .registrarUbicacionEvento(
            pos: pos,
            capturedAt: capturedAt,
            source: 'foto',
            visitId: widget.visitId,
          );
        }
        widget.onPhotoTaken?.call(file, base64String);
        widget.onPhotoTakenWithLocation?.call(PhotoCapture(
          file: file,
          base64: base64String,
          position: pos,
          capturedAt: capturedAt,
          ubicacionLocalId: ubicacionId,
        ));
      }
    } catch (e) {
      print('❌ Error al tomar foto: $e');
      if (!mounted) return;
      if (_esPermisoDenegado(e)) {
        _mostrarDialogoPermisoDenegado('cámara');
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al tomar foto: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _seleccionarDeGaleria() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
        maxWidth: 1024,
        maxHeight: 1024,
      );

      if (image != null) {
        final capturedAt = DateTime.now();
        final bytes = await image.readAsBytes();
        final base64String = base64Encode(bytes);
        final file = File(image.path);
        setState(() => _photo = file);
        // Galería: la ubicación es la actual del dispositivo, no la EXIF de
        // la foto. image_picker no expone EXIF de forma confiable; si en el
        // futuro se necesita, leer con `native_exif` desde image.path.
        final pos = await _capturarUbicacion();
        String? ubicacionId;
        if (pos != null) {
          ubicacionId = await LocationTrackingService.instance
              .registrarUbicacionEvento(
            pos: pos,
            capturedAt: capturedAt,
            source: 'foto_galeria',
            visitId: widget.visitId,
          );
        }
        widget.onPhotoTaken?.call(file, base64String);
        widget.onPhotoTakenWithLocation?.call(PhotoCapture(
          file: file,
          base64: base64String,
          position: pos,
          capturedAt: capturedAt,
          ubicacionLocalId: ubicacionId,
        ));
      }
    } catch (e) {
      print('❌ Error al seleccionar foto: $e');
      if (!mounted) return;
      if (_esPermisoDenegado(e)) {
        _mostrarDialogoPermisoDenegado('galería');
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al seleccionar foto: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// image_picker reporta permiso denegado como PlatformException con
  /// códigos como `camera_access_denied` / `photo_access_denied`.
  bool _esPermisoDenegado(Object e) {
    if (e is! PlatformException) return false;
    final code = e.code.toLowerCase();
    return code.contains('denied') || code.contains('permission');
  }

  Future<void> _mostrarDialogoPermisoDenegado(String recurso) async {
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Permiso necesario'),
        content: Text(
          'La app no tiene permiso para usar la $recurso. '
          'Actívalo en los ajustes del dispositivo para poder adjuntar fotos.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              Geolocator.openAppSettings();
            },
            child: const Text('Abrir ajustes'),
          ),
        ],
      ),
    );
  }

  Future<Position?> _capturarUbicacion() async {
    if (kIsWeb) return null;
    try {
      final enabled = await Geolocator.isLocationServiceEnabled();
      if (!enabled) return null;
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied ||
          perm == LocationPermission.deniedForever) {
        return null;
      }
      // best accuracy con tope de 12s: si el fix tarda más, se cae a
      // getLastKnownPosition para no dejar la foto sin coordenada.
      try {
        return await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.best,
          timeLimit: const Duration(seconds: 12),
        );
      } catch (_) {
        return await Geolocator.getLastKnownPosition();
      }
    } catch (e) {
      print('📍 [PhotoCapture] no se pudo capturar ubicación: $e');
      return null;
    }
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