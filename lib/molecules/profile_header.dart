import 'package:flutter/material.dart';
import '../core/app_colors.dart';
import '../atoms/avatar_widget.dart';

class ProfileHeader extends StatelessWidget {
  final String userName;
  final String? userRole;
  final String? userPhoto;

  const ProfileHeader({
    super.key,
    required this.userName,
    this.userRole,
    this.userPhoto,
  });

  String _getRoleName(String? role) {
    switch (role?.toLowerCase()) {
      case '1':
      case 'superadmin':
        return 'Administrador';
      case '2':
      case 'vendedor':
        return 'Vendedor';
      case '3':
      case 'gerente':
        return 'Gerente';
      case '5':
      case 'chofer':
        return 'Chofer';
      default:
        return role ?? 'Usuario';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 30),
      decoration: BoxDecoration(
        color: AppColors.primaryColor,
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(30),
          bottomRight: Radius.circular(30),
        ),
        boxShadow: [
          BoxShadow(color: AppColors.primaryColor.withOpacity(0.3), blurRadius: 20, spreadRadius: 2),
        ],
      ),
      child: Column(
        children: [
          // Avatar más grande para el perfil
          Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 4),
            ),
            child: AvatarWidget(
              name: userName,
              photoUrl: userPhoto,
              size: 100, // Sobrescribimos el tamaño por defecto
            ),
          ),
          const SizedBox(height: 20),
          Text(
            userName,
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
          ),
          const SizedBox(height: 5),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              _getRoleName(userRole),
              style: const TextStyle(fontSize: 14, color: Colors.white70),
            ),
          ),
        ],
      ),
    );
  }
}