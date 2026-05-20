import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'services/connectivity_service.dart';
import 'services/sync_service.dart';
import 'atoms/offline_banner.dart';
import 'pages/login_page.dart';
import 'core/app_colors.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Iniciar monitor de conexión
  ConnectivityService.instance.iniciarMonitor();
  
  // Iniciar auto-sync
  SyncService.iniciarAutoSync();

  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final ConnectivityService _connectivityService = ConnectivityService.instance;
  bool _isConnected = true;

  @override
  void initState() {
    super.initState();
    _checkConnection();
    _connectivityService.onConnectivityChanged.listen(_onConnectionChanged);
  }

  Future<void> _checkConnection() async {
    final conectado = await _connectivityService.isConnected();
    if (mounted) {
      setState(() => _isConnected = conectado);
    }
  }

  void _onConnectionChanged(ConnectivityResult result) {
    final conectado = result == ConnectivityResult.mobile ||
                      result == ConnectivityResult.wifi ||
                      result == ConnectivityResult.ethernet;
    if (mounted) {
      setState(() => _isConnected = conectado);
      
      if (conectado) {
        // Recuperó conexión - sincronizar
        SyncService.instance.sincronizarPendientes();
      }
    }
  }

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
      // Usar builder para envolver TODAS las pantallas
      builder: (context, child) {
        return Column(
          children: [
            // Banner offline visible en todas las pantallas
            if (!_isConnected)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                color: Colors.orange.shade700,
                child: SafeArea(
                  bottom: false,
                  child: Row(
                    children: [
                      const Icon(Icons.wifi_off, color: Colors.white, size: 18),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Text(
                          'Sin conexión - Modo offline',
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w500, fontSize: 13),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          'OFFLINE',
                          style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            // Contenido de la app
            Expanded(child: child ?? const SizedBox()),
          ],
        );
      },
      home: const LoginPage(),
    );
  }
}