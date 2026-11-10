import 'package:flutter/material.dart';
import 'my_car_colors.dart';
import 'my_car_palette.dart';

class AppTheme {
  // Mantener compatibilidad con código existente
  // Estos ahora apuntan a los colores centralizados
  static const Color primaryColor = MyCarColors.primary;
  static const Color secondaryColor = MyCarColors.secondary;
  static const Color accentColor = MyCarColors.secondary;

  static ThemeData get lightTheme {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: primaryColor,
      primary: primaryColor,
      secondary: secondaryColor,
      tertiary: accentColor,
      brightness: Brightness.light,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      extensions: const [MyCarPalette.light],
      dialogTheme: DialogThemeData(
        backgroundColor: MyCarPalette.light.background,
        surfaceTintColor: Colors.transparent,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: MyCarPalette.light.background,
        surfaceTintColor: Colors.transparent,
      ),
      dividerTheme: DividerThemeData(color: MyCarPalette.light.borderLight),
      scaffoldBackgroundColor: MyCarColors.backgroundLight,
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: colorScheme.onSurface,
        elevation: 0,
        centerTitle: true,
        scrolledUnderElevation: 1,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.bold,
          color: colorScheme.onSurface,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: MyCarColors.border, width: 1),
        ),
        color: MyCarColors.background,
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: MyCarColors.backgroundLight,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: MyCarColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: MyCarColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: MyCarColors.primary, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: MyCarColors.background,
        selectedItemColor: MyCarColors.primary,
        unselectedItemColor: MyCarColors.textSecondary,
        type: BottomNavigationBarType.fixed,
        elevation: 8,
        selectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600),
        unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.normal),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: MyCarColors.primary,
        foregroundColor: MyCarColors.white,
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }

  static ThemeData get darkTheme {
    final colorScheme =
        ColorScheme.fromSeed(
          seedColor: primaryColor,
          primary: primaryColor,
          secondary: secondaryColor,
          tertiary: accentColor,
          brightness: Brightness.dark,
        ).copyWith(
          // Superficies alineadas con la paleta (si no, Material 3 las tiñe de
          // violeta y no combinan con los grises de la app).
          // El botón relleno por defecto es índigo con texto blanco (como los que
          // fijan su estilo a mano), no el texto oscuro que propone Material 3.
          onPrimary: MyCarColors.white,
          surface: MyCarColors.gray900,
          onSurface: MyCarColors.gray50,
          onSurfaceVariant: MyCarColors.gray300,
          surfaceContainerLowest: MyCarColors.gray900,
          surfaceContainerLow: MyCarColors.gray800,
          surfaceContainer: MyCarColors.gray800,
          surfaceContainerHigh: MyCarColors.gray800,
          surfaceContainerHighest: MyCarColors.gray700,
          outline: MyCarColors.gray600,
          outlineVariant: MyCarColors.gray700,
        );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      extensions: const [MyCarPalette.dark],
      dialogTheme: DialogThemeData(
        backgroundColor: MyCarPalette.dark.background,
        surfaceTintColor: Colors.transparent,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: MyCarPalette.dark.background,
        surfaceTintColor: Colors.transparent,
      ),
      dividerTheme: DividerThemeData(color: MyCarPalette.dark.borderLight),
      // El índigo de marca no contrasta como texto sobre fondo oscuro: los
      // botones de texto, contorno y las pestañas usan el acento claro.
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: MyCarPalette.dark.accent),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: MyCarPalette.dark.accent,
        ),
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: MyCarPalette.dark.accent,
        indicatorColor: MyCarPalette.dark.accent,
        unselectedLabelColor: MyCarPalette.dark.textSecondary,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: MyCarColors.gray700,
        contentTextStyle: const TextStyle(color: MyCarColors.gray50),
        actionTextColor: MyCarPalette.dark.accent,
      ),
      scaffoldBackgroundColor: MyCarColors.backgroundDark,
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: colorScheme.onSurface,
        elevation: 0,
        centerTitle: true,
        scrolledUnderElevation: 1,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.bold,
          color: colorScheme.onSurface,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: MyCarColors.gray700, width: 1),
        ),
        color: MyCarColors.gray800,
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: MyCarColors.gray800,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: MyCarColors.gray700),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: MyCarColors.gray700),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: MyCarColors.primary, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: MyCarColors.gray800,
        selectedItemColor: MyCarColors.primary,
        unselectedItemColor: MyCarColors.textTertiary,
        type: BottomNavigationBarType.fixed,
        elevation: 8,
        selectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600),
        unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.normal),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: MyCarColors.primary,
        foregroundColor: MyCarColors.white,
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }
}
