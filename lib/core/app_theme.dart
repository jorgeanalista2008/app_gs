import 'package:flutter/material.dart';
import 'app_colors.dart';

class AppTheme {
  static ThemeData get lightTheme => ThemeData(
        useMaterial3: true,
        primaryColor: AppColors.primaryColor,
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.primaryColor,
          primary: AppColors.primaryColor,
          secondary: AppColors.secondaryColor,
          background: AppColors.backgroundColor,
        ),
        scaffoldBackgroundColor: AppColors.backgroundColor,
        dividerColor: AppColors.dividerColor,

        // Tema de la Barra de Aplicación (AppBar)
        appBarTheme: const AppBarTheme(
          elevation: 0,
          centerTitle: true,
          backgroundColor: AppColors.primaryColor,
          foregroundColor: Colors.white,
          iconTheme: IconThemeData(color: Colors.white, size: 22),
          actionsIconTheme: IconThemeData(color: Colors.white, size: 22),
          titleTextStyle: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.white,
            letterSpacing: 0.5,
          ),
        ),

        // Tema de Tarjetas (Cards)
        cardTheme: CardThemeData(
          elevation: 0,
          color: AppColors.cardColor,
          margin: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: Color(0xFFF1F5F9), width: 1), // Slate 100 border
          ),
        ),

        // Tema de Botón Elevado (ElevatedButton)
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primaryColor,
            foregroundColor: Colors.white,
            elevation: 0,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            textStyle: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
            ),
          ),
        ),

        // Tema de Botón Delineado (OutlinedButton)
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.primaryColor,
            elevation: 0,
            side: const BorderSide(color: AppColors.primaryColor, width: 1.5),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            textStyle: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
            ),
          ),
        ),

        // Tema de Diálogos (Dialog)
        dialogTheme: DialogThemeData(
          backgroundColor: AppColors.cardColor,
          elevation: 10,
          shadowColor: Colors.black.withValues(alpha: 0.1),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          titleTextStyle: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
          contentTextStyle: const TextStyle(
            fontSize: 14,
            color: AppColors.textSecondary,
          ),
        ),

        // Tema de Inputs
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFFF1F5F9), // Slate 100 para un fondo más sutil y moderno
          contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          labelStyle: const TextStyle(color: AppColors.textSecondary, fontSize: 14),
          hintStyle: const TextStyle(color: AppColors.textSecondary, fontSize: 14),
          prefixIconColor: AppColors.textSecondary,
          suffixIconColor: AppColors.textSecondary,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFE2E8F0), width: 1), // Slate 200
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.primaryColor, width: 2),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.errorColor, width: 1),
          ),
        ),
      );
}