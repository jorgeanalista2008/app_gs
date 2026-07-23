import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as p;
import '../repositories/generic_repository.dart';

/// Sube fotos al backend vía `POST /images/upload-base64` (público, sin auth)
/// y devuelve el id numérico de la imagen, que luego se envía como
/// `photo_1_id` / `photo_2_id` al registrar la visita.
///
/// `localPath` acepta tres formatos por retro-compatibilidad:
///   * Ruta de archivo (`/data/user/0/.../image.jpg`, `file:///...`)
///   * Data URI (`data:image/jpeg;base64,...`)
///   * Base64 puro (sin prefijo)
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
      final resolved = await _resolvePayload(localPath);
      if (resolved == null) return null;

      final response = await GenericRepository.instance.postOnline<Map<String, dynamic>>(
        path: '/images/upload-base64',
        body: {
          'data': 'data:${resolved.mime};base64,${resolved.base64}',
          'filename': resolved.filename,
          'mime': resolved.mime,
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

  Future<_ImagePayload?> _resolvePayload(String raw) async {
    if (raw.isEmpty) return null;

    // Data URI
    final dataUriMatch = RegExp(r'^data:([^;]+);base64,(.+)$').firstMatch(raw);
    if (dataUriMatch != null) {
      final mime = dataUriMatch.group(1)!;
      final b64 = dataUriMatch.group(2)!;
      final ext = _extFromMime(mime);
      return _ImagePayload(base64: b64, mime: mime, filename: 'upload.$ext');
    }

    // File path (absoluto o file://)
    final looksLikePath = raw.startsWith('/') ||
        raw.startsWith('file:') ||
        raw.contains(r'\') ||
        (raw.length > 2 && raw[1] == ':');
    if (looksLikePath) {
      final path = raw.startsWith('file:') ? Uri.parse(raw).toFilePath() : raw;
      final file = File(path);
      if (!await file.exists()) {
        print('⚠️ [ImageUpload] archivo no existe: $path');
        return null;
      }
      final bytes = await file.readAsBytes();
      final ext = p.extension(path).toLowerCase();
      final mime = _mimeByExt[ext] ?? 'image/jpeg';
      return _ImagePayload(
        base64: base64Encode(bytes),
        mime: mime,
        filename: p.basename(path),
      );
    }

    // Base64 puro (legacy: encuesta guardaba base64 en columna foto1_path)
    try {
      final normalized = raw.replaceAll(RegExp(r'\s'), '');
      base64Decode(normalized);
      return _ImagePayload(
        base64: normalized,
        mime: 'image/jpeg',
        filename: 'upload.jpg',
      );
    } catch (_) {
      print('⚠️ [ImageUpload] formato irreconocible (len=${raw.length})');
      return null;
    }
  }

  String _extFromMime(String mime) {
    switch (mime) {
      case 'image/png':
        return 'png';
      case 'image/webp':
        return 'webp';
      case 'image/gif':
        return 'gif';
      default:
        return 'jpg';
    }
  }
}

class _ImagePayload {
  final String base64;
  final String mime;
  final String filename;
  _ImagePayload({required this.base64, required this.mime, required this.filename});
}
