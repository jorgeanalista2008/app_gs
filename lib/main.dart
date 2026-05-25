import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'services/database_helper.dart';
import 'services/connectivity_service.dart';
import 'services/sync_queue_service.dart';
import 'services/conflict_resolver.dart';
import 'repositories/cliente_repository.dart';
import 'pages/login_page.dart';
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
  SyncQueueService.instance.start();
  // Limpia operaciones exitosas viejas en background.
  SyncQueueService.instance.purgeOldSuccessful();
  ConflictResolver.instance.purgeOld();

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
    );
  }
}