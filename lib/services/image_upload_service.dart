import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as p;
import '../repositories/generic_repository.dart';

/// Sube fotos locales al backend vía `POST /images/upload-base64`
/// (endpoint público, sin auth) y devuelve el id numérico de la imagen.
///
/// El backend no tiene columnas `photo_1`/`photo_2` en los DTOs de visitas
/// ni de prospectos: las fotos se guardan aparte en el módulo de imágenes y
/// se asocian por `owner_type`/`owner_id`. Por eso las visitas referencian
/// el id resultante en `extra_data` en vez de mandar la ruta del archivo.
class ImageUploadService {
  static final ImageUploadService instance = ImageUploadService._();
  ImageUploadService._();

  static const Map<String, String> _mimeByExt = {
    '.jpg': 'image/jpeg',
    '.jpeg': 'image/jpeg',
    '.png': 'image/png',
    '.webp': 'image/webp',
    '.gif': 'image/gif',
  };

  Future<int?> subirFoto({
    required String localPath,
    required String ownerType,
    String? ownerId,
  }) async {
    try {
      final file = File(localPath);
      if (!await file.exists()) {
        print('⚠️ [ImageUpload] archivo no existe (¿ya se limpió el caché?): $localPath');
        return null;
      }

      final bytes = await file.readAsBytes();
      final ext = p.extension(localPath).toLowerCase();
      final mime = _mimeByExt[ext] ?? 'image/jpeg';
      final base64Data = base64Encode(bytes);

      final response = await GenericRepository.instance.postOnline<Map<String, dynamic>>(
        path: '/images/upload-base64',
        body: {
          'data': 'data:$mime;base64,$base64Data',
          'filename': p.basename(localPath),
          'mime': mime,
          'owner_type': ownerType,
          if (ownerId != null) 'owner_id': ownerId,
        },
        fromJson: (json) => json,
      );

      final id = response?['id'];
      if (id == null) {
        print('⚠️ [ImageUpload] respuesta sin id de imagen: $response');
        return null;
      }
      final parsedId = id is int ? id : int.tryParse(id.toString());
      print('✅ [ImageUpload] foto subida id=$parsedId ($ownerType/${ownerId ?? '-'})');
      return parsedId;
    } catch (e) {
      print('❌ [ImageUpload] error subiendo foto: $e');
      return null;
    }
  }
}
