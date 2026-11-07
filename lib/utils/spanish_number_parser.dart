import 'currency_formatter.dart';

/// Número encontrado en una frase: [start] inclusive y [end] exclusivo son
/// índices de token.
class SpokenNumber {
  final double value;
  final int start;
  final int end;

  /// true cuando es solo "un/una/uno" (artículo), p. ej. "un tanqueo".
  final bool isArticle;

  const SpokenNumber({
    required this.value,
    required this.start,
    required this.end,
    this.isArticle = false,
  });

  @override
  String toString() => 'SpokenNumber($value, $start..$end)';
}

/// Minúsculas, sin tildes ni diéresis, y la ñ como n.
String normalizeSpanish(String text) {
  const from = 'áàäâéèëêíìïîóòöôúùüûñ';
  const to = 'aaaaeeeeiiiioooouuuun';
  final buffer = StringBuffer();
  for (final char in text.toLowerCase().split('')) {
    final index = from.indexOf(char);
    buffer.write(index >= 0 ? to[index] : char);
  }
  return buffer.toString();
}

final RegExp _tokenPattern = RegExp(r'[a-z]+|\d[\d.,]*\d|\d|\$');

/// Divide el texto en palabras, números ("50.000") y el símbolo `$`.
List<String> tokenizeSpanish(String text) =>
    _tokenPattern.allMatches(normalizeSpanish(text)).map((m) => m[0]!).toList();

const Map<String, int> _units = {
  'cero': 0,
  'un': 1,
  'uno': 1,
  'una': 1,
  'dos': 2,
  'tres': 3,
  'cuatro': 4,
  'cinco': 5,
  'seis': 6,
  'siete': 7,
  'ocho': 8,
  'nueve': 9,
  'diez': 10,
  'once': 11,
  'doce': 12,
  'trece': 13,
  'catorce': 14,
  'quince': 15,
  'dieciseis': 16,
  'diecisiete': 17,
  'dieciocho': 18,
  'diecinueve': 19,
  'veinte': 20,
  'veintiun': 21,
  'veintiuno': 21,
  'veintiuna': 21,
  'veintidos': 22,
  'veintitres': 23,
  'veinticuatro': 24,
  'veinticinco': 25,
  'veintiseis': 26,
  'veintisiete': 27,
  'veintiocho': 28,
  'veintinueve': 29,
};

const Map<String, int> _tens = {
  'treinta': 30,
  'cuarenta': 40,
  'cincuenta': 50,
  'sesenta': 60,
  'setenta': 70,
  'ochenta': 80,
  'noventa': 90,
};

const Map<String, int> _hundreds = {
  'cien': 100,
  'ciento': 100,
  'doscientos': 200,
  'doscientas': 200,
  'trescientos': 300,
  'trescientas': 300,
  'cuatrocientos': 400,
  'cuatrocientas': 400,
  'quinientos': 500,
  'quinientas': 500,
  'seiscientos': 600,
  'seiscientas': 600,
  'setecientos': 700,
  'setecientas': 700,
  'ochocientos': 800,
  'ochocientas': 800,
  'novecientos': 900,
  'novecientas': 900,
};

const Set<String> _millions = {'millon', 'millones'};
const Set<String> _thousandSlang = {'luca', 'lucas'};

final RegExp _digitToken = RegExp(r'^\d');

class _Group {
  final int value;
  final int end;
  const _Group(this.value, this.end);
}

/// Lee un grupo de 0 a 999: [centenas] [decenas [y unidad] | unidad 0-29].
_Group? _readGroup(List<String> tokens, int start) {
  var i = start;
  var value = 0;
  var consumed = false;

  if (i < tokens.length && _hundreds.containsKey(tokens[i])) {
    value += _hundreds[tokens[i]]!;
    i++;
    consumed = true;
  }

  if (i < tokens.length && _tens.containsKey(tokens[i])) {
    value += _tens[tokens[i]]!;
    i++;
    consumed = true;
    if (i + 1 < tokens.length && tokens[i] == 'y') {
      final unit = _units[tokens[i + 1]];
      if (unit != null && unit >= 1 && unit <= 9) {
        value += unit;
        i += 2;
      }
    }
  } else if (i < tokens.length && _units.containsKey(tokens[i])) {
    value += _units[tokens[i]]!;
    i++;
    consumed = true;
  }

  return consumed ? _Group(value, i) : null;
}

SpokenNumber? _readDigits(List<String> tokens, int start) {
  final base = parseAmount(tokens[start]);
  if (base == null) return null;

  var value = base;
  var end = start + 1;
  if (end < tokens.length) {
    final next = tokens[end];
    if (next == 'mil' || _thousandSlang.contains(next)) {
      value *= 1000;
      end++;
    } else if (_millions.contains(next)) {
      value *= 1000000;
      end++;
    }
  }
  return SpokenNumber(value: value, start: start, end: end);
}

SpokenNumber? _readWords(List<String> tokens, int start) {
  var total = 0.0;
  var i = start;
  var consumed = false;

  while (i < tokens.length) {
    final group = _readGroup(tokens, i);
    if (group != null) {
      final next = group.end < tokens.length ? tokens[group.end] : null;
      if (next == 'mil') {
        total += group.value * 1000;
        i = group.end + 1;
        consumed = true;
        continue;
      }
      if (next != null && _millions.contains(next)) {
        total += group.value * 1000000;
        i = group.end + 1;
        consumed = true;
        continue;
      }
      total += group.value;
      i = group.end;
      consumed = true;
      break;
    }
    if (tokens[i] == 'mil') {
      total += 1000;
      i++;
      consumed = true;
      continue;
    }
    if (_millions.contains(tokens[i])) {
      total += 1000000;
      i++;
      consumed = true;
      continue;
    }
    break;
  }

  if (!consumed) return null;
  final isArticle =
      i - start == 1 && const {'un', 'una', 'uno'}.contains(tokens[start]);
  return SpokenNumber(value: total, start: start, end: i, isArticle: isArticle);
}

/// Encuentra todos los números de la frase, escritos con dígitos
/// ("50.000", "80 mil", "1,5 millones") o con palabras ("ciento veinte mil").
List<SpokenNumber> extractSpokenNumbers(List<String> tokens) {
  final result = <SpokenNumber>[];
  var i = 0;
  while (i < tokens.length) {
    final number = _digitToken.hasMatch(tokens[i])
        ? _readDigits(tokens, i)
        : _readWords(tokens, i);
    if (number == null) {
      i++;
    } else {
      result.add(number);
      i = number.end;
    }
  }
  return result;
}
