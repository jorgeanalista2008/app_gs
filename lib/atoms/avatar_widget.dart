import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../core/app_colors.dart';
import 'package:cached_network_image/cached_network_image.dart';

class AvatarWidget extends StatelessWidget {
  final String? name;
  final String? photoUrl;
  final double size;
  final Color backgroundColor;
  final Color textColor;
  final bool showBorder;
  final Color borderColor;
  final double borderWidth;

  const AvatarWidget({
    super.key,
    this.name,
    this.photoUrl,
    this.size = 40,
    this.backgroundColor = Colors.white,
    this.textColor = AppColors.primaryColor,
    this.showBorder = false,
    this.borderColor = AppColors.primaryColor,
    this.borderWidth = 2.0,
  });

  @override
  Widget build(BuildContext context) {
    // Obtener iniciales
    final initials = _getInitials(name);
    
    // Decidir qué imagen mostrar
    final String? processedPhotoUrl = _processPhotoUrl(photoUrl);
    
    return Container(
      width: size,
      height: size,
      decoration: showBorder
          ? BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: borderColor,
                width: borderWidth,
              ),
            )
          : null,
      child: CircleAvatar(
        radius: size / 2,
        backgroundColor: backgroundColor,
        child: _buildAvatarContent(context, processedPhotoUrl, initials),
      ),
    );
  }

  Widget _buildAvatarContent(BuildContext context, String? imageUrl, String initials) {
    // Si no hay URL de imagen o está vacía, mostrar iniciales
    if (imageUrl == null || imageUrl.isEmpty) {
      return Text(
        initials,
        style: TextStyle(
          fontSize: size * 0.35,
          fontWeight: FontWeight.bold,
          color: textColor,
        ),
      );
    }

    // Si es una imagen en base64
    if (imageUrl.startsWith('data:image')) {
      try {
        final imageData = _decodeBase64Image(imageUrl);
        return ClipOval(
          child: Image.memory(
            imageData,
            width: size,
            height: size,
            fit: BoxFit.cover,
          ),
        );
      } catch (e) {
        print('Error decodificando base64: $e');
        return _buildInitialsFallback(initials);
      }
    }

    // Es una URL de red - Opción 1: Con CachedNetworkImage (recomendado)
    return _buildNetworkImage(imageUrl, initials);
    
    // Opción 2: Con Image.network (más simple, sin caché)
    // return _buildSimpleNetworkImage(imageUrl, initials);
  }

  Widget _buildNetworkImage(String imageUrl, String initials) {
    return CachedNetworkImage(
      imageUrl: imageUrl,
      imageBuilder: (context, imageProvider) => ClipOval(
        child: Image(
          image: imageProvider,
          width: size,
          height: size,
          fit: BoxFit.cover,
        ),
      ),
      placeholder: (context, url) => _buildLoadingPlaceholder(initials),
      errorWidget: (context, url, error) {
        print('Error cargando imagen: $error - URL: $url');
        return _buildInitialsFallback(initials);
      },
      fadeInDuration: const Duration(milliseconds: 300),
      fadeOutDuration: const Duration(milliseconds: 300),
    );
  }

  Widget _buildSimpleNetworkImage(String imageUrl, String initials) {
    return ClipOval(
      child: Image.network(
        imageUrl,
        width: size,
        height: size,
        fit: BoxFit.cover,
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return _buildLoadingPlaceholder(initials);
        },
        errorBuilder: (context, error, stackTrace) {
          print('Error cargando imagen: $error - URL: $imageUrl');
          return _buildInitialsFallback(initials);
        },
      ),
    );
  }

  Widget _buildLoadingPlaceholder(String initials) {
    return Container(
      width: size,
      height: size,
      color: Colors.grey[200],
      child: Center(
        child: SizedBox(
          width: size * 0.4,
          height: size * 0.4,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: AppColors.primaryColor,
          ),
        ),
      ),
    );
  }

  Widget _buildInitialsFallback(String initials) {
    return Text(
      initials,
      style: TextStyle(
        fontSize: size * 0.35,
        fontWeight: FontWeight.bold,
        color: textColor,
      ),
    );
  }

  String _getInitials(String? fullName) {
    if (fullName == null || fullName.isEmpty) {
      return '?';
    }

    final names = fullName.trim().split(' ');
    if (names.length >= 2) {
      final firstInitial = names[0][0];
      final secondInitial = names[1][0];
      return '${firstInitial.toUpperCase()}${secondInitial.toUpperCase()}';
    } else if (fullName.length >= 2) {
      return fullName.substring(0, 2).toUpperCase();
    } else if (fullName.isNotEmpty) {
      return fullName.substring(0, 1).toUpperCase();
    }
    
    return '?';
  }

  String? _processPhotoUrl(String? photoUrl) {
    if (photoUrl == null || photoUrl.isEmpty) {
      return null;
    }

    // Si ya es una URL completa o base64, devolver tal cual
    if (photoUrl.startsWith('http') || photoUrl.startsWith('data:image')) {
      return photoUrl;
    }

    // Si es una ruta relativa que comienza con /
    if (photoUrl.startsWith('/')) {
      // Asumiendo que tu dominio base es el mismo
      return 'https://app.grupo-solsumed.com/admin/storage/users/$photoUrl';
    }

    // Si es solo un nombre de archivo o ruta relativa sin /
    // Asume que está en una carpeta de uploads
    if (!photoUrl.contains('/')) {
      return 'https://app.grupo-solsumed.com/admin/storage/users/$photoUrl';
    }

    // Para otras rutas relativas
    return 'https://app.grupo-solsumed.com/$photoUrl';
  }

  Uint8List _decodeBase64Image(String base64String) {
    try {
      // Eliminar el prefijo 'data:image/...;base64,'
      final String data = base64String.split(',').last;
      return base64Decode(data);
    } catch (e) {
      throw Exception('Error decodificando imagen base64: $e');
    }
  }
}