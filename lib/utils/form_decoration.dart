import 'package:flutter/material.dart';
import 'my_car_colors.dart';

/// Decoración estándar de campos de formulario de MyCar.
InputDecoration myCarInputDecoration({
  required String label,
  String? hint,
  double radius = 12,
  Color fillColor = MyCarColors.backgroundLight,
}) {
  OutlineInputBorder border(Color color, double width) => OutlineInputBorder(
    borderRadius: BorderRadius.circular(radius),
    borderSide: BorderSide(color: color, width: width),
  );

  return InputDecoration(
    labelText: label,
    hintText: hint,
    filled: true,
    fillColor: fillColor,
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    labelStyle: const TextStyle(
      color: MyCarColors.textSecondary,
      fontSize: 14,
      fontWeight: FontWeight.w500,
    ),
    hintStyle: const TextStyle(color: MyCarColors.textTertiary, fontSize: 15),
    border: border(MyCarColors.border, 1.5),
    enabledBorder: border(MyCarColors.border, 1.5),
    focusedBorder: border(MyCarColors.primary, 2),
    errorBorder: border(MyCarColors.error, 1.5),
    focusedErrorBorder: border(MyCarColors.error, 2),
  );
}

const TextStyle myCarInputTextStyle = TextStyle(
  color: MyCarColors.textPrimary,
  fontSize: 15,
  fontWeight: FontWeight.w500,
);
