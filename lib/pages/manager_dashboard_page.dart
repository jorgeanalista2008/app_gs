import 'package:flutter/material.dart';
import '../core/app_colors.dart';
import '../organisms/manager_dashboard_content.dart';

class ManagerDashboardPage extends StatelessWidget {
  const ManagerDashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundColor,
      appBar: AppBar(
        title: const Text('Panel Gerencial'),
        backgroundColor: AppColors.primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: const ManagerDashboardContent(),
    );
  }
}