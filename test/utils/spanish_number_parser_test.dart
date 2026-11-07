import 'package:flutter_test/flutter_test.dart';
import 'package:new_my_car_app/utils/spanish_number_parser.dart';

List<double> numbersIn(String text) =>
    extractSpokenNumbers(tokenizeSpanish(text)).map((n) => n.value).toList();

void main() {
  group('normalizeSpanish', () {
    test('lowercases and strips accents', () {
      expect(normalizeSpanish('Gasté CINCUENTA mil'), 'gaste cincuenta mil');
      expect(normalizeSpanish('Miércoles, año'), 'miercoles, ano');
    });
  });

  group('tokenizeSpanish', () {
    test('keeps numbers with separators and the dollar sign', () {
      expect(tokenizeSpanish(r'Pagué $50.000 en gasolina'), [
        'pague',
        r'$',
        '50.000',
        'en',
        'gasolina',
      ]);
    });

    test('does not include trailing punctuation in numbers', () {
      expect(tokenizeSpanish('Gasté 50.'), ['gaste', '50']);
    });
  });

  group('extractSpokenNumbers with digits', () {
    test('reads plain numbers and thousands separators', () {
      expect(numbersIn('gasté 50000'), [50000]);
      expect(numbersIn('gasté 50.000'), [50000]);
      expect(numbersIn('gasté 1.234.567'), [1234567]);
    });

    test('applies "mil", "millones" and "lucas" to digits', () {
      expect(numbersIn('gasté 50 mil'), [50000]);
      expect(numbersIn('costó 2 millones'), [2000000]);
      expect(numbersIn('costó 1,5 millones'), [1500000]);
      expect(numbersIn('me dieron 80 lucas'), [80000]);
    });

    test('finds several numbers in one sentence', () {
      expect(numbersIn('10 litros por 40 mil'), [10, 40000]);
    });
  });

  group('extractSpokenNumbers with words', () {
    test('units, teens and twenties', () {
      expect(numbersIn('cero'), [0]);
      expect(numbersIn('siete'), [7]);
      expect(numbersIn('quince'), [15]);
      expect(numbersIn('veintiuno'), [21]);
      expect(numbersIn('veintinueve'), [29]);
    });

    test('tens with "y"', () {
      expect(numbersIn('treinta'), [30]);
      expect(numbersIn('treinta y cinco'), [35]);
      expect(numbersIn('noventa y nueve'), [99]);
    });

    test('hundreds', () {
      expect(numbersIn('cien'), [100]);
      expect(numbersIn('ciento veinte'), [120]);
      expect(numbersIn('doscientos cincuenta'), [250]);
      expect(numbersIn('quinientos'), [500]);
      expect(numbersIn('novecientos noventa y nueve'), [999]);
    });

    test('thousands', () {
      expect(numbersIn('mil'), [1000]);
      expect(numbersIn('dos mil'), [2000]);
      expect(numbersIn('cincuenta mil'), [50000]);
      expect(numbersIn('ciento veinte mil'), [120000]);
      expect(numbersIn('mil quinientos'), [1500]);
      expect(numbersIn('cincuenta mil quinientos'), [50500]);
      expect(numbersIn('doscientos cincuenta mil'), [250000]);
    });

    test('millions', () {
      expect(numbersIn('un millon'), [1000000]);
      expect(numbersIn('dos millones'), [2000000]);
      expect(numbersIn('dos millones quinientos mil'), [2500000]);
    });

    test('does not merge separate numbers', () {
      expect(numbersIn('dos tres'), [2, 3]);
    });

    test('ignores words that are not numbers', () {
      expect(numbersIn('gasolina en el taller'), isEmpty);
    });
  });

  group('article detection', () {
    test('flags a lone "un/una" as an article', () {
      final numbers = extractSpokenNumbers(tokenizeSpanish('compré un filtro'));

      expect(numbers, hasLength(1));
      expect(numbers.single.isArticle, isTrue);
    });

    test('"un millón" is a real number, not an article', () {
      final numbers = extractSpokenNumbers(tokenizeSpanish('un millon'));

      expect(numbers.single.isArticle, isFalse);
      expect(numbers.single.value, 1000000);
    });
  });
}
