import 'package:flutter/material.dart';
import 'my_car_colors.dart';
import 'my_car_palette.dart';

/// Decoración estándar de campos de formulario de MyCar. Los colores salen del
/// tema (claro u oscuro) a través de [context]; [fillColor] los reemplaza.
InputDecoration myCarInputDecoration(
  BuildContext context, {
  required String label,
  String? hint,
  double radius = 12,
  Color? fillColor,
}) {
  OutlineInputBorder border(Color color, double width) => OutlineInputBorder(
    borderRadius: BorderRadius.circular(radius),
    borderSide: BorderSide(color: color, width: width),
  );

  return InputDecoration(
    labelText: label,
    hintText: hint,
    filled: true,
    fillColor: fillColor ?? context.palette.backgroundLight,
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    labelStyle: TextStyle(
      color: context.palette.textSecondary,
      fontSize: 14,
      fontWeight: FontWeight.w500,
    ),
    hintStyle: TextStyle(color: context.palette.textTertiary, fontSize: 15),
    border: border(context.palette.border, 1.5),
    enabledBorder: border(context.palette.border, 1.5),
    focusedBorder: border(MyCarColors.primary, 2),
    errorBorder: border(MyCarColors.error, 1.5),
    focusedErrorBorder: border(MyCarColors.error, 2),
  );
}

/// Estilo del texto que escribe el usuario en un campo de formulario.
TextStyle myCarInputTextStyle(BuildContext context) => TextStyle(
  color: context.palette.textPrimary,
  fontSize: 15,
  fontWeight: FontWeight.w500,
);
