import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/app_colors.dart';
import '../organisms/app_drawer.dart';
import '../organisms/dashboard_content.dart';
import 'login_page.dart';
import 'scanner_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  String? _userName;
  String? _userRole;
  String? _userPhoto;

  @override
  void initState() { super.initState(); _loadUserData(); }
  
  void _loadUserData() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _userName = prefs.getString('user_name') ?? 'Usuario';
      _userRole = prefs.getString('user_role'); // <--- Recuperamos el rol
      _userPhoto = prefs.getString('user_photo');
    });
  }

  void _logout() async {
    final prefs = await SharedPreferences.getInstance();
    prefs.clear();
    if(mounted) Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const LoginPage()));
  }

  void _goToScanner() {
    Navigator.push(context, MaterialPageRoute(builder: (context) => const ScannerPage()));
  }

    
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Inicio'),
        backgroundColor: AppColors.primaryColor,
        foregroundColor: Colors.white,
      ),
      drawer: AppDrawer(
        userName: _userName ?? 'Usuario',
        userRole: _userRole,
        userPhoto: _userPhoto,
        onLogout: _logout,
        onScanPressed: _goToScanner,
      ),
      body: DashboardContent(
        userName: _userName ?? 'Usuario',
        userRole: _userRole ?? '0', // <--- PASAMOS EL ROL AL DASHBOARD
        onScanPressed: _goToScanner,
      ),
    );
  }
}