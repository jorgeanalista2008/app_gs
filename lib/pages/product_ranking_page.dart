import 'package:flutter/material.dart';
import '../core/app_colors.dart';
import '../organisms/product_ranking_content.dart';

class ProductRankingPage extends StatelessWidget {
  const ProductRankingPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundColor,
      appBar: AppBar(
        title: const Text('Productos Gerencia'),
        backgroundColor: AppColors.primaryColor,
        foregroundColor: Colors.white,
      ),
      body: const ProductRankingContent(),
    );
  }
}