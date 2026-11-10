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

  group('VoiceTransactionDraft.toTransaction', () {
    final now = DateTime(2026, 11, 10, 12);

    VoiceTransactionDraft parse(String text) =>
        VoiceTransactionParser.parse(text, now: now);

    test('combustible conserva litros y kilometraje', () {
      final t = parse(
        'gasté ochenta mil en gasolina 10 litros 45200 km',
      ).toTransaction(userId: 'u1', carId: 'c1');

      expect(t.userId, 'u1');
      expect(t.carId, 'c1');
      expect(t.type, TransactionType.expense);
      expect(t.category, TransactionCategory.fuel);
      expect(t.amount, 80000);
      expect(t.liters, 10);
      expect(t.odometerKm, 45200);
      expect(t.description, 'Combustible');
    });

    test('mantenimiento conserva el kilometraje pero no los litros', () {
      final t = parse(
        'pagué cien mil en el taller 45200 km',
      ).toTransaction(userId: 'u1', carId: 'c1');

      expect(t.category, TransactionCategory.maintenance);
      expect(t.odometerKm, 45200);
      expect(t.liters, isNull);
    });

    test('un ingreso no lleva categoría, litros ni kilometraje', () {
      final t = parse(
        'me pagaron ciento veinte mil por una carrera',
      ).toTransaction(userId: 'u1', carId: 'c1');

      expect(t.type, TransactionType.income);
      expect(t.category, isNull);
      expect(t.liters, isNull);
      expect(t.odometerKm, isNull);
      expect(t.amount, 120000);
    });

    test('usa la fecha interpretada', () {
      final t = parse(
        'gasté diez mil en peaje ayer',
      ).toTransaction(userId: 'u1', carId: 'c1');

      expect(t.date, DateTime(2026, 11, 9));
    });
  });

  group('frases del rediseño (es-CO)', () {
    final now = DateTime(2026, 11, 10, 12); // martes

    VoiceTransactionDraft parse(
      String text, {
      List<VoiceVehicle> vehicles = const [],
    }) => VoiceTransactionParser.parse(
      text,
      now: now,
      defaultType: TransactionType.expense,
      vehicles: vehicles,
    );

    group('los chips de ejemplo', () {
      test('"Ingreso de 150 mil"', () {
        final d = parse('Ingreso de 150 mil');
        expect(d.type, TransactionType.income);
        expect(d.amount, 150000);
        expect(d.category, isNull);
      });

      test('"Gasolina 60 mil"', () {
        final d = parse('Gasolina 60 mil');
        expect(d.type, TransactionType.expense);
        expect(d.category, TransactionCategory.fuel);
        expect(d.amount, 60000);
      });

      test('"Cambio de aceite 120 mil ayer"', () {
        final d = parse('Cambio de aceite 120 mil ayer');
        expect(d.type, TransactionType.expense);
        expect(d.category, TransactionCategory.maintenance);
        expect(d.amount, 120000);
        expect(d.date, DateTime(2026, 11, 9));
      });
    });

    group('montos', () {
      const cases = {
        'gasolina 60 mil': 60000.0,
        'gasté 60.000 en gasolina': 60000.0,
        'sesenta mil de gasolina': 60000.0,
        'ciento cincuenta mil de ingreso': 150000.0,
        '1,2 millones de repuesto': 1200000.0,
        'un millón doscientos de taller': 1200000.0,
        'un millón doscientos cincuenta de taller': 1250000.0,
        'dos millones de ingreso': 2000000.0,
      };
      cases.forEach((phrase, amount) {
        test('"$phrase" → $amount', () {
          expect(parse(phrase).amount, amount);
        });
      });
    });

    group('tipo', () {
      const income = [
        'ingreso de 80 mil',
        'gané 200 mil hoy',
        'hice una carrera de 45 mil',
        'me pagaron 80 mil',
        'carrera 25 mil',
      ];
      const expense = [
        'gasto de 40 mil',
        'pagué 30 mil',
        'gasolina 60 mil',
        'tanqueé 70 mil',
        'aceite 90 mil',
        'peaje 12 mil',
        'lavada 30 mil',
        'parqueadero 8 mil',
        'repuesto 90 mil',
        'taller 150 mil',
      ];
      for (final phrase in income) {
        test('"$phrase" es ingreso', () {
          expect(parse(phrase).type, TransactionType.income);
        });
      }
      for (final phrase in expense) {
        test('"$phrase" es gasto', () {
          expect(parse(phrase).type, TransactionType.expense);
        });
      }

      test('si no queda claro, es gasto', () {
        expect(parse('cuarenta mil').type, TransactionType.expense);
      });
    });

    group('categoría', () {
      const cases = {
        'gasolina 60 mil': TransactionCategory.fuel,
        'tanqueada 70 mil': TransactionCategory.fuel,
        'aceite 90 mil': TransactionCategory.maintenance,
        'taller 150 mil': TransactionCategory.maintenance,
        'repuesto 90 mil': TransactionCategory.maintenance,
        'peaje 12 mil': TransactionCategory.other,
        'parqueadero 8 mil': TransactionCategory.other,
        'lavada 30 mil': TransactionCategory.other,
      };
      cases.forEach((phrase, category) {
        test('"$phrase" → ${category.name}', () {
          expect(parse(phrase).category, category);
        });
      });
    });

    group('fecha', () {
      test('por defecto es hoy', () {
        expect(parse('gasolina 60 mil').date, DateTime(2026, 11, 10));
      });
      test('hoy', () {
        expect(parse('gasolina 60 mil hoy').date, DateTime(2026, 11, 10));
      });
      test('ayer', () {
        expect(parse('gasolina 60 mil ayer').date, DateTime(2026, 11, 9));
      });
      test('antier', () {
        expect(parse('peaje 12 mil antier').date, DateTime(2026, 11, 8));
      });
      test('el lunes (el pasado más reciente)', () {
        expect(parse('lavada 30 mil el lunes').date, DateTime(2026, 11, 9));
      });
      test('el martes dicho un martes es el de la semana pasada', () {
        expect(parse('lavada 30 mil el martes').date, DateTime(2026, 11, 3));
      });
      test('el 5 de noviembre', () {
        expect(
          parse('parqueadero 8 mil el 5 de noviembre').date,
          DateTime(2026, 11, 5),
        );
      });
    });

    group('vehículo', () {
      const mazda = VoiceVehicle(id: 'mazda', brand: 'Mazda', model: '3');
      const duster = VoiceVehicle(
        id: 'duster',
        brand: 'Renault',
        model: 'Duster',
      );
      const corolla = VoiceVehicle(
        id: 'corolla',
        brand: 'Toyota',
        model: 'Corolla',
      );
      const yaris = VoiceVehicle(id: 'yaris', brand: 'Toyota', model: 'Yaris');

      test('sin nombrar ninguno no hay vehículo mencionado', () {
        final d = parse('gasolina 60 mil', vehicles: [mazda, duster]);
        expect(d.mentionedCarId, isNull);
      });

      test('"el Mazda"', () {
        final d = parse('gasolina 60 mil del Mazda', vehicles: [mazda, duster]);
        expect(d.mentionedCarId, 'mazda');
      });

      test('"la Duster"', () {
        final d = parse('aceite 120 mil la Duster', vehicles: [mazda, duster]);
        expect(d.mentionedCarId, 'duster');
      });

      test('por el modelo o por la marca', () {
        expect(
          parse(
            'peaje 12 mil renault',
            vehicles: [mazda, duster],
          ).mentionedCarId,
          'duster',
        );
      });

      test('la marca repetida es ambigua, pero el modelo desempata', () {
        expect(
          parse(
            'gasolina 60 mil toyota',
            vehicles: [corolla, yaris],
          ).mentionedCarId,
          isNull,
        );
        expect(
          parse(
            'gasolina 60 mil del Yaris',
            vehicles: [corolla, yaris],
          ).mentionedCarId,
          'yaris',
        );
        expect(
          parse(
            'gasolina 60 mil del toyota yaris',
            vehicles: [corolla, yaris],
          ).mentionedCarId,
          'yaris',
        );
      });

      test('ignora acentos y mayúsculas', () {
        const v = VoiceVehicle(id: 'x', brand: 'Citroën', model: 'C4');
        expect(
          parse('peaje 12 mil CITROEN', vehicles: [v]).mentionedCarId,
          'x',
        );
      });
    });
  });

  group('VoiceTransactionDraft: ediciones de la revisión', () {
    final now = DateTime(2026, 11, 10, 12);
    VoiceTransactionDraft fuel() => VoiceTransactionParser.parse(
      'gasolina 60 mil 10 litros',
      now: now,
      defaultType: TransactionType.expense,
    );

    test('withType a ingreso quita la categoría y los litros al guardar', () {
      final d = fuel().withType(TransactionType.income);

      expect(d.type, TransactionType.income);
      expect(d.category, isNull);
      expect(d.description, 'Gasolina 60 mil 10 litros');
      final t = d.toTransaction(userId: 'u', carId: 'c');
      expect(t.category, isNull);
      expect(t.liters, isNull);
    });

    test('withType a egreso desde ingreso usa "Otros"', () {
      final income = VoiceTransactionParser.parse(
        'ingreso de 150 mil',
        now: now,
      );

      final d = income.withType(TransactionType.expense);

      expect(d.type, TransactionType.expense);
      expect(d.category, TransactionCategory.other);
    });

    test('withCategory actualiza la categoría y la descripción automática', () {
      final d = fuel().withCategory(TransactionCategory.maintenance);

      expect(d.category, TransactionCategory.maintenance);
      expect(d.description, 'Mantenimiento');
    });

    test('withCategory no hace nada en un ingreso', () {
      final income = VoiceTransactionParser.parse(
        'ingreso de 150 mil',
        now: now,
      );

      expect(income.withCategory(TransactionCategory.fuel).category, isNull);
    });

    test('withAmount y withDate cambian solo eso', () {
      final d = fuel().withAmount(75000).withDate(DateTime(2026, 11, 1, 18));

      expect(d.amount, 75000);
      expect(d.date, DateTime(2026, 11, 1));
      expect(d.category, TransactionCategory.fuel);
    });

    test('withAmount(null) deja el monto vacío', () {
      expect(fuel().withAmount(null).hasAmount, isFalse);
    });
  });
}
