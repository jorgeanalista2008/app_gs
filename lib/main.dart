import 'package:flutter/material.dart';
import 'core/app_theme.dart';
import 'pages/login_page.dart';
import 'services/sync_service.dart';
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SyncService.iniciarAutoSync();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Grupo Solsumed, CA',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: const LoginPage(),
    );
  }
}
