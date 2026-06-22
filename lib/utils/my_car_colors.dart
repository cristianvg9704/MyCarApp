import 'package:flutter/material.dart';

/// Colores centralizados de la aplicación MyCar
/// Basados en la paleta de la landing page
/// 
/// Para cambiar los colores de toda la app, modifica este archivo únicamente.
class MyCarColors {
  // ============================================
  // INDIGO - Color Principal de Marca
  // ============================================
  static const Color indigo50 = Color(0xFFEEF2FF);
  static const Color indigo100 = Color(0xFFE0E7FF);
  static const Color indigo600 = Color(0xFF4F46E5);
  static const Color indigo700 = Color(0xFF4338CA);

  // ============================================
  // BLUE - Color Secundario
  // ============================================
  static const Color blue50 = Color(0xFFEFF6FF);
  static const Color blue100 = Color(0xFFDBEAFE);
  static const Color blue600 = Color(0xFF2563EB);

  // ============================================
  // GRAY - Textos y Fondos
  // ============================================
  static const Color gray50 = Color(0xFFF9FAFB);
  static const Color gray300 = Color(0xFFD1D5DB);
  static const Color gray400 = Color(0xFF9CA3AF);
  static const Color gray600 = Color(0xFF4B5563);
  static const Color gray700 = Color(0xFF374151);
  static const Color gray800 = Color(0xFF1F2937);
  static const Color gray900 = Color(0xFF111827);

  // ============================================
  // ESTADOS Y UTILIDADES
  // ============================================
  static const Color success = Color(0xFF10B981);
  static const Color white = Color(0xFFFFFFFF);
  static const Color error = Color(0xFFEF4444);
  static const Color warning = Color(0xFFF59E0B);

  // ============================================
  // COLORES SEMÁNTICOS (Recomendado usar estos)
  // ============================================
  
  /// Color principal de la marca - Usar para botones principales, textos destacados
  static const Color primary = indigo600;
  
  /// Variante oscura del color principal - Usar para estados hover, botones presionados
  static const Color primaryDark = indigo700;
  
  /// Variante clara del color principal - Usar para fondos suaves, iconos
  static const Color primaryLight = indigo100;
  
  /// Color secundario - Usar para gradientes, elementos secundarios
  static const Color secondary = blue600;
  
  /// Variante clara del color secundario
  static const Color secondaryLight = blue100;
  
  /// Texto principal - Usar para títulos, textos importantes
  static const Color textPrimary = gray900;
  
  /// Texto secundario - Usar para textos de apoyo, descripciones
  static const Color textSecondary = gray600;
  
  /// Texto terciario - Usar para placeholders, textos deshabilitados
  static const Color textTertiary = gray400;
  
  /// Fondo principal - Usar para Scaffold backgrounds
  static const Color background = white;
  
  /// Fondo alternativo claro - Usar para tarjetas, secciones
  static const Color backgroundLight = gray50;
  
  /// Fondo oscuro - Usar para modos oscuros o secciones destacadas
  static const Color backgroundDark = gray900;
  
  /// Color para bordes y líneas divisorias
  static const Color border = gray300;

  // ============================================
  // GRADIENTES PREDEFINIDOS
  // ============================================
  
  /// Gradiente principal (indigo-600 a blue-600)
  /// Usar para botones destacados, headers importantes
  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [indigo600, blue600],
  );

  /// Gradiente suave (indigo-100 a blue-100)
  /// Usar para fondos de tarjetas, secciones suaves
  static const LinearGradient softGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [indigo100, blue100],
  );

  /// Gradiente hero (blue-50 a indigo-100)
  /// Usar para secciones hero, fondos principales
  static const LinearGradient heroGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [blue50, indigo100],
  );

  /// Gradiente claro (indigo-50 a blue-50)
  /// Usar para fondos muy suaves
  static const LinearGradient lightGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [indigo50, blue50],
  );
}
