// services/image_qr_service.dart - VERSIÓN CORREGIDA
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

/// Servicio para escanear códigos QR desde imágenes estáticas
/// Permite a los conductores escanear códigos QR usando fotografías
/// cuando no pueden hacerlo en tiempo real
class ImageQrService {
  static final ImageQrService _instance = ImageQrService._internal();
  factory ImageQrService() => _instance;
  ImageQrService._internal();

  final ImagePicker _picker = ImagePicker();

  /// Analiza una imagen y extrae el código QR si existe
  /// Retorna el código QR encontrado o null si no hay código
  Future<String?> analyzeImageForQr(String imagePath) async {
    try {
      print('🔍 Analizando imagen: $imagePath');
      
      // Crear controlador temporal para analizar la imagen
      final controller = MobileScannerController(
        detectionSpeed: DetectionSpeed.noDuplicates,
        facing: CameraFacing.back,
      );

      // Analizar la imagen usando MobileScanner
      // NOTA: analyzeImage no tiene parámetro 'formats' en esta versión
      final result = await controller.analyzeImage(
        imagePath,
      );

      controller.dispose();

      if (result != null && result.barcodes.isNotEmpty) {
        final barcode = result.barcodes.first;
        final code = barcode.rawValue;
        
        if (code != null && code.isNotEmpty) {
          // Verificar que sea un QR code
          if (barcode.format == BarcodeFormat.qrCode) {
            print('✅ QR encontrado en imagen: $code');
            return code;
          } else {
            print('⚠️ Código encontrado pero no es QR: ${barcode.format}');
            return code; // Retornamos igual, puede ser útil
          }
        }
      }

      print('⚠️ No se encontró código QR en la imagen');
      return null;
    } catch (e) {
      print('❌ Error analizando imagen: $e');
      return null;
    }
  }

  /// Abre la cámara para tomar una foto
  /// Retorna la ruta del archivo de la foto tomada
  Future<File?> takePhotoWithCamera() async {
    try {
      print('📷 Abriendo cámara para tomar foto...');
      
      final XFile? photo = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 85,
        maxWidth: 1920,
        maxHeight: 1080,
        preferredCameraDevice: CameraDevice.rear,
      );

      if (photo != null) {
        print('✅ Foto tomada: ${photo.path}');
        return File(photo.path);
      }

      print('⚠️ Usuario canceló la toma de foto');
      return null;
    } catch (e) {
      print('❌ Error tomando foto: $e');
      return null;
    }
  }

  /// Abre la galería para seleccionar una imagen
  /// Retorna la ruta del archivo seleccionado
  Future<File?> pickImageFromGallery() async {
    try {
      print('🖼️ Abriendo galería...');
      
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
        maxWidth: 1920,
        maxHeight: 1080,
      );

      if (image != null) {
        print('✅ Imagen seleccionada: ${image.path}');
        return File(image.path);
      }

      print('⚠️ Usuario canceló la selección');
      return null;
    } catch (e) {
      print('❌ Error seleccionando imagen: $e');
      return null;
    }
  }

  /// Flujo completo: Tomar foto y extraer QR
  Future<QrScanResult> takePhotoAndScan() async {
    try {
      final photo = await takePhotoWithCamera();
      
      if (photo == null) {
        return QrScanResult.cancelled();
      }

      final qrCode = await analyzeImageForQr(photo.path);
      
      if (qrCode != null) {
        return QrScanResult.success(
          code: qrCode,
          imagePath: photo.path,
        );
      }

      return QrScanResult.noQrFound(imagePath: photo.path);
    } catch (e) {
      return QrScanResult.error(message: e.toString());
    }
  }

  /// Flujo completo: Seleccionar de galería y extraer QR
  Future<QrScanResult> pickFromGalleryAndScan() async {
    try {
      final image = await pickImageFromGallery();
      
      if (image == null) {
        return QrScanResult.cancelled();
      }

      final qrCode = await analyzeImageForQr(image.path);
      
      if (qrCode != null) {
        return QrScanResult.success(
          code: qrCode,
          imagePath: image.path,
        );
      }

      return QrScanResult.noQrFound(imagePath: image.path);
    } catch (e) {
      return QrScanResult.error(message: e.toString());
    }
  }
}

/// Resultado del escaneo de QR desde imagen
class QrScanResult {
  final bool success;
  final String? code;
  final String? imagePath;
  final String? errorMessage;
  final QrScanStatus status;

  QrScanResult({
    required this.success,
    this.code,
    this.imagePath,
    this.errorMessage,
    required this.status,
  });

  factory QrScanResult.success({required String code, String? imagePath}) {
    return QrScanResult(
      success: true,
      code: code,
      imagePath: imagePath,
      status: QrScanStatus.success,
    );
  }

  factory QrScanResult.noQrFound({String? imagePath}) {
    return QrScanResult(
      success: false,
      imagePath: imagePath,
      errorMessage: 'No se encontró ningún código QR en la imagen',
      status: QrScanStatus.noQrFound,
    );
  }

  factory QrScanResult.cancelled() {
    return QrScanResult(
      success: false,
      errorMessage: 'Operación cancelada por el usuario',
      status: QrScanStatus.cancelled,
    );
  }

  factory QrScanResult.error({required String message}) {
    return QrScanResult(
      success: false,
      errorMessage: message,
      status: QrScanStatus.error,
    );
  }

  @override
  String toString() {
    return 'QrScanResult(success: $success, code: $code, status: $status)';
  }
}

enum QrScanStatus {
  success,
  noQrFound,
  cancelled,
  error,
}
