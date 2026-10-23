import 'package:intl/intl.dart';

/// Formato de dinero de la app. Por ahora solo pesos colombianos (COP):
/// sin decimales y con punto como separador de miles (`$1.234.567`).
class CurrencyFormatter {
  CurrencyFormatter._();

  static final NumberFormat _number = NumberFormat('#,##0', 'es_CO');

  static String format(double amount) {
    final sign = amount < 0 ? '-' : '';
    return '$sign\$${_number.format(amount.abs())}';
  }

  /// Formato con signo explícito para movimientos (`+$1.000` / `-$1.000`).
  static String formatSigned(double signedAmount) {
    final sign = signedAmount < 0 ? '-' : '+';
    return '$sign\$${_number.format(signedAmount.abs())}';
  }
}

/// Convierte lo que escribe el usuario en un número.
///
/// Acepta `50000`, `50.000`, `50,000`, `1.234.567`, `12.5`, `12,5` y
/// `1.234,56`. Un único separador seguido de exactamente tres dígitos se
/// interpreta como separador de miles. Devuelve null si no es un número.
double? parseAmount(String input) {
  var text = input.replaceAll(RegExp(r'[\s\$]'), '');
  if (text.isEmpty) return null;

  final hasDot = text.contains('.');
  final hasComma = text.contains(',');

  if (hasDot && hasComma) {
    final decimalSeparator = text.lastIndexOf('.') > text.lastIndexOf(',')
        ? '.'
        : ',';
    final thousandsSeparator = decimalSeparator == '.' ? ',' : '.';
    text = text
        .replaceAll(thousandsSeparator, '')
        .replaceAll(decimalSeparator, '.');
  } else if (hasDot || hasComma) {
    final separator = hasDot ? '.' : ',';
    final isThousands = RegExp(
      '^\\d{1,3}(\\$separator\\d{3})+\$',
    ).hasMatch(text);
    text = isThousands
        ? text.replaceAll(separator, '')
        : text.replaceAll(',', '.');
  }

  return double.tryParse(text);
}
