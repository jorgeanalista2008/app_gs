import 'package:app_gs/core/app_colors.dart';
import 'package:flutter/material.dart';
import '../organisms/driver_routes_content.dart'; // Importa el Organismo que acabamos de crear
// Importa tu página de Login

class DriverPage extends StatelessWidget {
  const DriverPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white, // Fondo blanco limpio
      appBar: AppBar(
        title: const Text('Mis viajes'),
        backgroundColor: AppColors.primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      // Aquí llamamos al Organismo
      body: const DriverRoutesContent(), 
      // Opcional: Agregar un botón para salir (Log Out).
    );
  }
}