import 'package:flutter/material.dart';
import 'services/database_helper.dart';
import 'services/sync_service.dart';
import 'pages/login_page.dart';
import 'core/app_colors.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Inicializar BD y crear usuario maestro
  final db = DatabaseHelper.instance;
  await db.insertarUsuarioMaestro();

  // Iniciar SyncService local
  SyncService.iniciar();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Grupo Solsumed',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primaryColor: AppColors.primaryColor,
        colorScheme: ColorScheme.fromSeed(seedColor: AppColors.primaryColor),
        useMaterial3: true,
      ),
      home: const LoginPage(),
    );
  }
}