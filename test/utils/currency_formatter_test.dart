import 'package:flutter_test/flutter_test.dart';
import 'package:new_my_car_app/utils/currency_formatter.dart';

void main() {
  group('CurrencyFormatter', () {
    test('formats pesos without decimals and with dot thousands separator', () {
      expect(CurrencyFormatter.format(1234567), '\$1.234.567');
      expect(CurrencyFormatter.format(0), '\$0');
      expect(CurrencyFormatter.format(50000), '\$50.000');
    });

    test('rounds away decimals', () {
      expect(CurrencyFormatter.format(1999.6), '\$2.000');
    });

    test('formats negative amounts', () {
      expect(CurrencyFormatter.format(-15000), '-\$15.000');
    });

    test('formatSigned adds an explicit sign', () {
      expect(CurrencyFormatter.formatSigned(1000), '+\$1.000');
      expect(CurrencyFormatter.formatSigned(-1000), '-\$1.000');
    });
  });

  group('parseAmount', () {
    test('parses plain integers and decimals', () {
      expect(parseAmount('50000'), 50000);
      expect(parseAmount('12.5'), 12.5);
      expect(parseAmount('12,5'), 12.5);
      expect(parseAmount('0.75'), 0.75);
    });

    test('treats a single separator followed by 3 digits as thousands', () {
      expect(parseAmount('50.000'), 50000);
      expect(parseAmount('50,000'), 50000);
      expect(parseAmount('1.234.567'), 1234567);
    });

    test('handles both separators using the last one as decimal', () {
      expect(parseAmount('1.234,56'), 1234.56);
      expect(parseAmount('1,234.56'), 1234.56);
    });

    test('ignores spaces and the currency symbol', () {
      expect(parseAmount(' \$ 50.000 '), 50000);
    });

    test('returns null for empty or invalid input', () {
      expect(parseAmount(''), isNull);
      expect(parseAmount('   '), isNull);
      expect(parseAmount('abc'), isNull);
      expect(parseAmount('12abc'), isNull);
    });
  });
}
