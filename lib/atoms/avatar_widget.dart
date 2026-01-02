import 'package:flutter/material.dart';
import '../core/app_colors.dart';

class AvatarWidget extends StatelessWidget {
  final String? name;
  final String? photoUrl;
  final double size; // Nueva propiedad de tamaño

  const AvatarWidget({
    super.key,
    this.name,
    this.photoUrl,
    this.size = 40, // Tamaño por defecto (mismo que el del Drawer)
  });

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: size / 2, // Usamos la mitad del tamaño para el radio
      backgroundColor: Colors.white,
      child: photoUrl != null && photoUrl!.isNotEmpty
          ? ClipOval(
              child: Image.network(
                photoUrl!,
                width: size,
                height: size,
                fit: BoxFit.cover,
              ),
            )
          : Text(
              name != null ? name![0].toUpperCase() : 'U',
              style: TextStyle(
                fontSize: (size / 2) * 1.5, // El texto escala con el avatar
                color: AppColors.primaryColor,
              ),
            ),
    );
  }
}