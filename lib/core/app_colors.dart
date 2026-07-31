import 'package:flutter/material.dart';

/// Paleta oficial Solsumed. Alineada con el dashboard web:
///   - Azul institucional #0143A4 (headers, tabs activas, links).
///   - Teal #0F766E como acento (health score positivo, precios competitivos).
///   - Grises Slate para textos y fondos.
///
/// Cualquier color nuevo pasa por este archivo — no hardcodear Colors.blue
/// ni Color(0xFF...) en widgets.
class AppColors {
  // ─── Solsumed ──────────────────────────────────────
  static const primaryColor = Color(0xFF0143A4);    // Azul institucional Solsumed
  static const primaryDark = Color(0xFF073B7A);     // Navy para hovers / activos
  static const secondaryColor = Color(0xFF0F766E);  // Teal acento (marca dashboard)
  static const accentColor = Color(0xFF0891B2);     // Cyan secundario para chips

  // ─── Fondos ───────────────────────────────────────
  static const backgroundColor = Color(0xFFF8FAFC); // Slate 50, ultra limpio
  static const cardColor = Colors.white;

  // ─── Semánticas ───────────────────────────────────
  static const errorColor = Color(0xFFEF4444);      // Rojo
  static const successColor = Color(0xFF10B981);    // Verde entregas
  static const warningColor = Color(0xFFF59E0B);    // Ámbar pendientes
  static const infoColor = Color(0xFF3B82F6);       // Info neutro

  // ─── Textos ───────────────────────────────────────
  static const textPrimary = Color(0xFF0F172A);     // Slate 900
  static const textSecondary = Color(0xFF64748B);   // Slate 500
  static const textMuted = Color(0xFF94A3B8);       // Slate 400
  static const dividerColor = Color(0xFFE2E8F0);    // Slate 200
}
