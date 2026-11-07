import 'package:flutter_test/flutter_test.dart';
import 'package:new_my_car_app/models/car_transaction.dart';
import 'package:new_my_car_app/services/voice_transaction_parser.dart';

void main() {
  // Viernes 23 de octubre de 2026
  final now = DateTime(2026, 10, 23, 15, 30);
  final today = DateTime(2026, 10, 23);

  VoiceTransactionDraft parse(
    String text, {
    TransactionType defaultType = TransactionType.income,
  }) => VoiceTransactionParser.parse(text, now: now, defaultType: defaultType);

  group('type', () {
    test('expense verbs', () {
      expect(parse('gasté 50 mil').type, TransactionType.expense);
      expect(parse('pagué cuarenta mil').type, TransactionType.expense);
      expect(
        parse('compré un filtro por 30 mil').type,
        TransactionType.expense,
      );
    });

    test('income verbs', () {
      expect(parse('me pagaron 120 mil').type, TransactionType.income);
      expect(parse('ingreso de 80 mil').type, TransactionType.income);
      expect(
        parse('cobré cien mil por una carrera').type,
        TransactionType.income,
      );
    });

    test('category words imply an expense when no verb is present', () {
      expect(parse('50 mil de gasolina').type, TransactionType.expense);
      expect(parse('cambio de aceite 120 mil').type, TransactionType.expense);
    });

    test('falls back to the default type when nothing is clear', () {
      expect(parse('50 mil').type, TransactionType.income);
      expect(
        parse('50 mil', defaultType: TransactionType.expense).type,
        TransactionType.expense,
      );
    });

    test('when both appear, the first verb wins', () {
      expect(parse('me pagaron y gasté 20 mil').type, TransactionType.income);
      expect(parse('gasté 20 mil y me pagaron').type, TransactionType.expense);
    });
  });

  group('amount', () {
    test('digits, words and slang', () {
      expect(parse('gasté 50000 en gasolina').amount, 50000);
      expect(parse('gasté 50.000 en gasolina').amount, 50000);
      expect(parse(r'gasté $50.000').amount, 50000);
      expect(parse('gasté cincuenta mil').amount, 50000);
      expect(parse('gasté ciento veinte mil pesos').amount, 120000);
      expect(parse('me dieron 80 lucas').amount, 80000);
      expect(parse('costó dos millones quinientos mil').amount, 2500000);
    });

    test('is null when no amount is said', () {
      final draft = parse('tanqueé la moto');

      expect(draft.amount, isNull);
      expect(draft.hasAmount, isFalse);
    });

    test('ignores the article "un" as an amount', () {
      expect(parse('compré un filtro').amount, isNull);
    });

    test('does not mistake liters, kilometers or dates for the amount', () {
      final draft = parse(
        'tanqueé 10 litros por 40 mil a los 45200 kilómetros hace 3 días',
      );

      expect(draft.amount, 40000);
      expect(draft.liters, 10);
      expect(draft.odometerKm, 45200);
    });

    test('prefers the number marked as pesos', () {
      expect(parse('compré 4 llantas, 800 mil pesos').amount, 800000);
    });
  });

  group('category', () {
    test('fuel', () {
      for (final text in [
        'gasté 50 mil en gasolina',
        'tanqueé por 60 mil',
        'eché acpm por 90 mil',
        'gasté 40 mil en gas',
      ]) {
        expect(parse(text).category, TransactionCategory.fuel, reason: text);
      }
    });

    test('maintenance', () {
      for (final text in [
        'gasté 120 mil en cambio de aceite',
        'pagué 300 mil al mecánico',
        'compré llantas por 800 mil',
        'revisión de frenos 90 mil',
      ]) {
        expect(
          parse(text).category,
          TransactionCategory.maintenance,
          reason: text,
        );
      }
    });

    test('other expenses', () {
      expect(
        parse('pagué 12 mil de peaje').category,
        TransactionCategory.other,
      );
      expect(
        parse('gasté 30 mil en el parqueadero').category,
        TransactionCategory.other,
      );
    });

    test('an expense with no known word is "other"', () {
      expect(parse('gasté 15 mil').category, TransactionCategory.other);
    });

    test('incomes have no category', () {
      expect(parse('me pagaron 100 mil').category, isNull);
    });

    test('liters alone imply fuel', () {
      expect(
        parse('eché 10 litros por 40 mil').category,
        TransactionCategory.fuel,
      );
    });
  });

  group('fuel and odometer', () {
    test('liters', () {
      expect(parse('tanqueé diez litros por 40 mil').liters, 10);
    });

    test('gallons are converted to liters', () {
      expect(parse('tanqueé 2 galones por 30 mil').liters, 7.57);
    });

    test('odometer with "kilometraje" and with units', () {
      expect(parse('aceite 120 mil kilometraje 45200').odometerKm, 45200);
      expect(parse('aceite 120 mil a los 45 mil kilómetros').odometerKm, 45000);
      expect(parse('gasté 50 mil en gasolina con 45200 km').odometerKm, 45200);
    });

    test('fuel data is dropped when the movement is not fuel', () {
      final draft = parse('me pagaron 100 mil, 10 litros');

      expect(draft.type, TransactionType.income);
      expect(draft.liters, isNull);
    });

    test('odometer is dropped for "other" expenses', () {
      expect(parse('pagué 12 mil de peaje a los 45200 km').odometerKm, isNull);
    });
  });

  group('date', () {
    test('defaults to today', () {
      expect(parse('gasté 50 mil').date, today);
      expect(parse('hoy gasté 50 mil').date, today);
    });

    test('ayer and anteayer', () {
      expect(parse('ayer gasté 50 mil').date, DateTime(2026, 10, 22));
      expect(parse('gasté 50 mil anteayer').date, DateTime(2026, 10, 21));
      expect(parse('gasté 50 mil antier').date, DateTime(2026, 10, 21));
      expect(parse('gasté 50 mil antes de ayer').date, DateTime(2026, 10, 21));
    });

    test('hace N días and semanas', () {
      expect(parse('gasté 50 mil hace 3 días').date, DateTime(2026, 10, 20));
      expect(parse('gasté 50 mil hace tres días').date, DateTime(2026, 10, 20));
      expect(
        parse('gasté 50 mil hace una semana').date,
        DateTime(2026, 10, 16),
      );
      expect(parse('gasté 50 mil hace un día').date, DateTime(2026, 10, 22));
    });

    test('weekday names resolve to the most recent past occurrence', () {
      expect(parse('el lunes gasté 50 mil').date, DateTime(2026, 10, 19));
      expect(parse('gasté 50 mil el miércoles').date, DateTime(2026, 10, 21));
      // Hoy es viernes: "el viernes" se entiende como el pasado
      expect(parse('el viernes gasté 50 mil').date, DateTime(2026, 10, 16));
    });

    test('day and month', () {
      expect(
        parse('el 15 de octubre gasté 50 mil').date,
        DateTime(2026, 10, 15),
      );
      expect(parse('el 5 de marzo gasté 50 mil').date, DateTime(2026, 3, 5));
    });

    test('a day/month in the future means last year', () {
      expect(
        parse('el 30 de diciembre gasté 50 mil').date,
        DateTime(2025, 12, 30),
      );
    });

    test('date numbers are not taken as the amount', () {
      expect(parse('el 15 de octubre gasté 50 mil').amount, 50000);
      expect(parse('hace 3 días gasté 50 mil').amount, 50000);
    });
  });

  group('description', () {
    test('uses the category label for fuel and maintenance expenses', () {
      expect(parse('gasté 50 mil en gasolina').description, 'Combustible');
      expect(parse('cambio de aceite 120 mil').description, 'Mantenimiento');
    });

    test('uses the capitalized transcript otherwise', () {
      expect(parse('me pagaron 100 mil').description, 'Me pagaron 100 mil');
      expect(
        parse('pagué 12 mil de peaje').description,
        'Pagué 12 mil de peaje',
      );
    });

    test('keeps the original transcript trimmed', () {
      expect(parse('  gasté 50 mil  ').transcript, 'gasté 50 mil');
    });

    test('empty input yields an empty draft', () {
      final draft = parse('');

      expect(draft.amount, isNull);
      expect(draft.description, isEmpty);
      expect(draft.date, today);
      expect(draft.type, TransactionType.income);
    });
  });

  group('full sentences', () {
    test('fuel expense with everything', () {
      final draft = parse(
        'ayer tanqueé diez litros de gasolina por cincuenta mil con 45200 kilómetros',
      );

      expect(draft.type, TransactionType.expense);
      expect(draft.category, TransactionCategory.fuel);
      expect(draft.amount, 50000);
      expect(draft.liters, 10);
      expect(draft.odometerKm, 45200);
      expect(draft.date, DateTime(2026, 10, 22));
    });

    test('income from a trip', () {
      final draft = parse(
        'me pagaron ciento veinte mil por una carrera al aeropuerto',
      );

      expect(draft.type, TransactionType.income);
      expect(draft.amount, 120000);
      expect(draft.category, isNull);
      expect(draft.date, today);
    });

    test('maintenance with odometer', () {
      final draft = parse(
        'pagué 180 mil por cambio de aceite y filtro con kilometraje 52000',
      );

      expect(draft.type, TransactionType.expense);
      expect(draft.category, TransactionCategory.maintenance);
      expect(draft.amount, 180000);
      expect(draft.odometerKm, 52000);
    });
  });
}
