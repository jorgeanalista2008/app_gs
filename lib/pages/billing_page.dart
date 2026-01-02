import 'package:flutter/material.dart';
import '../core/app_colors.dart';
import '../organisms/billing_content.dart';

class BillingPage extends StatelessWidget {
  const BillingPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundColor,
      appBar: AppBar(
        title: const Text('Gestión de Facturación'),
        backgroundColor: AppColors.primaryColor,
        foregroundColor: Colors.white,
      ),
      body: const BillingContent(),
    );
  }
}