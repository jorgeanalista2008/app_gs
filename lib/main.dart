import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'services/database_helper.dart';
import 'services/connectivity_service.dart';
import 'services/sync_queue_service.dart';
import 'services/conflict_resolver.dart';
import 'services/background_sync_service.dart';
import 'services/location_tracking_service.dart';
import 'repositories/cliente_repository.dart';
import 'repositories/pregunta_repository.dart';
import 'pages/login_page.dart';
import 'pages/biometric_login_page.dart';
import 'pages/home_page.dart';
import 'core/app_colors.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Inicializar BD y crear usuario maestro
  final db = DatabaseHelper.instance;
  await db.insertarUsuarioMaestro();

  // Monitor de conectividad + cola de sync con auto-drain al recuperar red
  ConnectivityService.instance.iniciarMonitor();
  // Handlers de éxito para mapear server_id tras push.
  ClienteRepository.registerSyncHandlers();
  PreguntaRepository.registerSyncHandlers();
  LocationTrackingService.registerSyncHandlers();
  // Arranca el tracker sin depender de sesión. Si no hay permisos aún,
  // el servicio lo detecta y no arranca; se re-intenta al login o cuando
  // el usuario habilite permisos desde ajustes del SO.
  unawaited(LocationTrackingService.instance.start());
  SyncQueueService.instance.start();
  // Limpia operaciones exitosas viejas en background.
  SyncQueueService.instance.purgeOldSuccessful();
  ConflictResolver.instance.purgeOld();
  // Sincronización periódica del SO para cuando la app está cerrada.
  BackgroundSyncService.initialize();

  runApp(const ProviderScope(child: MyApp()));
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
      routes: {
        '/login': (context) => const LoginPage(),
        '/biometric': (context) => const BiometricLoginPage(),
        '/home': (context) => const HomePage(),
      },
    );
  }
}