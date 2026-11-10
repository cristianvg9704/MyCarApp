import 'package:flutter/material.dart';
import 'my_car_colors.dart';

/// Colores que **dependen del fondo** (texto, bordes, superficies y tintes) en
/// su variante clara y oscura. Se lee del tema: `context.palette.textPrimary`.
///
/// Los colores de marca y de estado (`MyCarColors.primary`, `success`, `error`,
/// `warning`…) se ven bien en ambos modos y se siguen usando directo. Usar
/// `MyCarColors.textPrimary`, `border`, `background`… en una pantalla es un bug
/// en modo oscuro (texto casi negro sobre fondo oscuro): hay un test que lo
/// impide.
@immutable
class MyCarPalette extends ThemeExtension<MyCarPalette> {
  /// Superficies: tarjetas, hojas, diálogos.
  final Color background;

  /// Fondo de pantalla y de bloques "hundidos" dentro de una tarjeta.
  final Color backgroundLight;

  /// Fondo de controles neutros (botones circulares, control segmentado).
  final Color surfaceMuted;

  final Color textPrimary;
  final Color textSecondary;
  final Color textTertiary;

  /// Etiquetas pequeñas (labels de sección y de filas).
  final Color textLabel;

  final Color border;
  final Color borderLight;

  /// Fondo suave del color de marca (chips, íconos).
  final Color primaryLight;

  /// Fondo todavía más suave del color de marca (chips de ejemplo).
  final Color primarySoft;

  /// Fondo suave del color secundario.
  final Color secondaryLight;

  /// Ingreso y gasto: texto/ícono y su fondo suave.
  final Color income;
  final Color incomeLight;
  final Color expense;
  final Color expenseLight;

  /// Color de marca para **texto e íconos** sobre una superficie (más claro en
  /// modo oscuro para que contraste).
  final Color accent;

  /// Color secundario (azul) para texto e íconos sobre una superficie.
  final Color accentSecondary;

  const MyCarPalette({
    required this.background,
    required this.backgroundLight,
    required this.surfaceMuted,
    required this.textPrimary,
    required this.textSecondary,
    required this.textTertiary,
    required this.textLabel,
    required this.border,
    required this.borderLight,
    required this.primaryLight,
    required this.primarySoft,
    required this.secondaryLight,
    required this.income,
    required this.incomeLight,
    required this.expense,
    required this.expenseLight,
    required this.accent,
    required this.accentSecondary,
  });

  static const MyCarPalette light = MyCarPalette(
    background: MyCarColors.white,
    backgroundLight: MyCarColors.gray50,
    surfaceMuted: MyCarColors.gray100,
    textPrimary: MyCarColors.gray900,
    textSecondary: MyCarColors.gray600,
    textTertiary: MyCarColors.gray400,
    textLabel: MyCarColors.gray500,
    border: MyCarColors.gray300,
    borderLight: MyCarColors.gray200,
    primaryLight: MyCarColors.indigo100,
    primarySoft: MyCarColors.indigo50,
    secondaryLight: MyCarColors.blue100,
    income: MyCarColors.income,
    incomeLight: MyCarColors.incomeLight,
    expense: MyCarColors.expense,
    expenseLight: MyCarColors.expenseLight,
    accent: MyCarColors.primary,
    accentSecondary: MyCarColors.secondary,
  );

  static const MyCarPalette dark = MyCarPalette(
    background: MyCarColors.gray800,
    backgroundLight: MyCarColors.gray900,
    surfaceMuted: MyCarColors.gray700,
    textPrimary: MyCarColors.gray50,
    textSecondary: MyCarColors.gray300,
    textTertiary: MyCarColors.gray400,
    textLabel: MyCarColors.gray400,
    border: MyCarColors.gray700,
    borderLight: MyCarColors.gray700,
    primaryLight: Color(0xFF312E81), // indigo-900
    primarySoft: Color(0xFF272566),
    secondaryLight: Color(0xFF1E3A8A), // blue-900
    income: Color(0xFF34D399), // emerald-400
    incomeLight: Color(0xFF064E3B), // emerald-900
    expense: Color(0xFFF87171), // red-400
    expenseLight: Color(0xFF7F1D1D), // red-900
    accent: Color(0xFF818CF8), // indigo-400
    accentSecondary: Color(0xFF60A5FA), // blue-400
  );

  @override
  MyCarPalette copyWith({
    Color? background,
    Color? backgroundLight,
    Color? surfaceMuted,
    Color? textPrimary,
    Color? textSecondary,
    Color? textTertiary,
    Color? textLabel,
    Color? border,
    Color? borderLight,
    Color? primaryLight,
    Color? primarySoft,
    Color? secondaryLight,
    Color? income,
    Color? incomeLight,
    Color? expense,
    Color? expenseLight,
    Color? accent,
    Color? accentSecondary,
  }) => MyCarPalette(
    background: background ?? this.background,
    backgroundLight: backgroundLight ?? this.backgroundLight,
    surfaceMuted: surfaceMuted ?? this.surfaceMuted,
    textPrimary: textPrimary ?? this.textPrimary,
    textSecondary: textSecondary ?? this.textSecondary,
    textTertiary: textTertiary ?? this.textTertiary,
    textLabel: textLabel ?? this.textLabel,
    border: border ?? this.border,
    borderLight: borderLight ?? this.borderLight,
    primaryLight: primaryLight ?? this.primaryLight,
    primarySoft: primarySoft ?? this.primarySoft,
    secondaryLight: secondaryLight ?? this.secondaryLight,
    income: income ?? this.income,
    incomeLight: incomeLight ?? this.incomeLight,
    expense: expense ?? this.expense,
    expenseLight: expenseLight ?? this.expenseLight,
    accent: accent ?? this.accent,
    accentSecondary: accentSecondary ?? this.accentSecondary,
  );

  @override
  MyCarPalette lerp(ThemeExtension<MyCarPalette>? other, double t) {
    if (other is! MyCarPalette) return this;
    Color mix(Color a, Color b) => Color.lerp(a, b, t)!;
    return MyCarPalette(
      background: mix(background, other.background),
      backgroundLight: mix(backgroundLight, other.backgroundLight),
      surfaceMuted: mix(surfaceMuted, other.surfaceMuted),
      textPrimary: mix(textPrimary, other.textPrimary),
      textSecondary: mix(textSecondary, other.textSecondary),
      textTertiary: mix(textTertiary, other.textTertiary),
      textLabel: mix(textLabel, other.textLabel),
      border: mix(border, other.border),
      borderLight: mix(borderLight, other.borderLight),
      primaryLight: mix(primaryLight, other.primaryLight),
      primarySoft: mix(primarySoft, other.primarySoft),
      secondaryLight: mix(secondaryLight, other.secondaryLight),
      income: mix(income, other.income),
      incomeLight: mix(incomeLight, other.incomeLight),
      expense: mix(expense, other.expense),
      expenseLight: mix(expenseLight, other.expenseLight),
      accent: mix(accent, other.accent),
      accentSecondary: mix(accentSecondary, other.accentSecondary),
    );
  }
}

extension MyCarPaletteContext on BuildContext {
  /// Paleta del tema actual (clara u oscura). Si el tema no la define (por
  /// ejemplo un `MaterialApp` de prueba sin `AppTheme`), usa la clara.
  MyCarPalette get palette =>
      Theme.of(this).extension<MyCarPalette>() ?? MyCarPalette.light;
}
