import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:new_my_car_app/models/car.dart';
import 'package:new_my_car_app/models/car_transaction.dart';
import 'package:new_my_car_app/providers/car_provider.dart';
import 'package:new_my_car_app/providers/transaction_provider.dart';
import 'package:new_my_car_app/services/speech_recognizer.dart';
import 'package:new_my_car_app/services/transaction_repository.dart';
import 'package:new_my_car_app/widgets/voice_entry_sheet.dart';

import '../helpers/fake_speech_recognizer.dart';

class _FakeCarProvider extends CarProvider {
  @override
  List<Car> get cars => [
    Car(
      id: 'c1',
      userId: 'u1',
      brand: 'Mazda',
      model: '3',
      year: 2021,
      plateNumber: 'MZD321',
    ),
    Car(id: 'c2', userId: 'u1', brand: 'Renault', model: 'Duster', year: 2023),
  ];

  @override
  bool get isLoading => false;

  @override
  Future<void> loadCars() async {}
}

class _FakeRepository implements TransactionRepository {
  final List<CarTransaction> added = [];
  Object? failWith;

  @override
  Future<String> add(CarTransaction transaction) async {
    if (failWith != null) throw failWith!;
    added.add(transaction);
    return 'tx-${added.length}';
  }

  @override
  Future<List<CarTransaction>> getByCar(String carId) async => added;

  @override
  Future<void> update(CarTransaction transaction) async {}

  @override
  Future<void> delete(String id) async {}
}

void main() {
  late _FakeRepository repository;
  late FakeSpeechRecognizer recognizer;
  late DateTime clock;
  late int haptics;
  late int settingsOpened;
  VoiceEntryOutcome? outcome;
  var closed = false;

  setUp(() {
    repository = _FakeRepository();
    recognizer = FakeSpeechRecognizer();
    clock = DateTime(2026, 11, 10, 12);
    haptics = 0;
    settingsOpened = 0;
    outcome = null;
    closed = false;
  });

  /// Abre la hoja como lo hace la app (modal desde abajo).
  Future<void> openSheet(
    WidgetTester tester, {
    String? Function()? currentUserId,
  }) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<CarProvider>(
            create: (_) => _FakeCarProvider(),
          ),
          ChangeNotifierProvider(
            create: (_) => TransactionProvider(repository: repository),
          ),
        ],
        child: MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () async {
                    outcome = await showModalBottomSheet<VoiceEntryOutcome>(
                      context: context,
                      isScrollControlled: true,
                      builder: (_) => VoiceEntrySheet(
                        carId: 'c1',
                        speechRecognizer: recognizer,
                        currentUserId: currentUserId ?? () => 'u1',
                        now: () => clock,
                        haptic: () async => haptics++,
                        openSettings: () async => settingsOpened++,
                      ),
                    );
                    closed = true;
                  },
                  child: const Text('abrir'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();
  }

  /// Escuchando hay animaciones en bucle: se avanza el tiempo a mano.
  Future<void> settle(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
  }

  Future<void> startListening(WidgetTester tester) async {
    await tester.tap(find.byKey(const Key('voice_mic_button')));
    await settle(tester);
  }

  /// Escucha, dice la frase y deja la hoja en "Revisa y guarda".
  Future<void> dictate(WidgetTester tester, String phrase) async {
    await startListening(tester);
    recognizer.say(phrase, isFinal: true);
    await tester.pumpAndSettle();
  }

  Future<void> tapKey(WidgetTester tester, String key) async {
    await tester.tap(find.byKey(Key(key)));
    await tester.pumpAndSettle();
  }

  FilledButton saveButton(WidgetTester tester) => tester.widget<FilledButton>(
    find.descendant(
      of: find.byKey(const Key('voice_save_button')),
      matching: find.byType(FilledButton),
    ),
  );

  String text(WidgetTester tester, String key) =>
      tester.widget<Text>(find.byKey(Key(key))).data!;

  group('Estado 1: Listo', () {
    testWidgets('muestra título, vehículo, micrófono y ejemplos', (
      tester,
    ) async {
      await openSheet(tester);

      expect(find.text('Registrar por voz'), findsOneWidget);
      expect(find.text('Mazda 3'), findsOneWidget);
      expect(find.text('Toca el micrófono y habla'), findsOneWidget);
      expect(find.text('PRUEBA DECIR'), findsOneWidget);
      expect(find.text('“Ingreso de 150 mil”'), findsOneWidget);
      expect(find.text('“Gasolina 60 mil”'), findsOneWidget);
      expect(find.text('“Cambio de aceite 120 mil ayer”'), findsOneWidget);
    });

    testWidgets('no escucha hasta que se toca el micrófono', (tester) async {
      await openSheet(tester);

      expect(recognizer.initializeCalls, 0);
      expect(recognizer.isListening, isFalse);
    });

    testWidgets('no muestra el formulario de movimientos', (tester) async {
      await openSheet(tester);

      expect(find.byType(TextFormField), findsNothing);
      expect(find.text('Registrar Movimiento'), findsNothing);
      expect(find.text('Guardar Ingreso'), findsNothing);
    });

    testWidgets('el micrófono mide 104 px dentro de un halo de 156 px', (
      tester,
    ) async {
      await openSheet(tester);

      final mic = tester.getSize(find.byKey(const Key('voice_mic_tap')));
      expect(mic, const Size(104, 104));
      final halo = find.byWidgetPredicate(
        (w) =>
            w is Container &&
            w.constraints?.maxWidth == 156 &&
            (w.decoration as BoxDecoration?)?.color != null,
      );
      expect(halo, findsOneWidget);
    });

    testWidgets('el chip abre el selector y cambia el vehículo', (
      tester,
    ) async {
      await openSheet(tester);

      await tapKey(tester, 'voice_vehicle_chip');
      expect(find.text('¿A qué vehículo?'), findsOneWidget);
      await tapKey(tester, 'voice_vehicle_option_c2');

      expect(find.text('Renault Duster'), findsOneWidget);
      expect(find.text('Mazda 3'), findsNothing);
    });

    testWidgets('cerrar con la X descarta la hoja', (tester) async {
      await openSheet(tester);

      await tapKey(tester, 'voice_close_button');

      expect(closed, isTrue);
      expect(outcome, isNull);
    });

    testWidgets('los botones táctiles miden al menos 44x44', (tester) async {
      await openSheet(tester);

      for (final key in [
        'voice_close_button',
        'voice_vehicle_chip',
        'voice_mic_tap',
      ]) {
        final size = tester.getSize(find.byKey(Key(key)));
        expect(size.width, greaterThanOrEqualTo(44), reason: key);
        expect(size.height, greaterThanOrEqualTo(44), reason: key);
      }
    });
  });

  group('Estado 2: Escuchando', () {
    testWidgets('al tocar el micrófono empieza a escuchar', (tester) async {
      await openSheet(tester);

      await startListening(tester);

      expect(recognizer.initializeCalls, 1);
      expect(recognizer.isListening, isTrue);
      expect(find.text('Escuchando…'), findsOneWidget);
      expect(find.text('Toca para terminar'), findsOneWidget);
      expect(find.text('LO QUE ENTENDÍ'), findsOneWidget);
      expect(find.byKey(const Key('voice_stop_square')), findsOneWidget);
      expect(find.byKey(const Key('voice_cancel_button')), findsOneWidget);
    });

    testWidgets('vibra al empezar', (tester) async {
      await openSheet(tester);

      await startListening(tester);

      expect(haptics, 1);
    });

    testWidgets('muestra el texto parcial en vivo', (tester) async {
      await openSheet(tester);
      await startListening(tester);

      recognizer.say('gasolina', isFinal: false);
      await settle(tester);
      expect(text(tester, 'voice_transcript'), 'gasolina');

      recognizer.say('gasolina sesenta mil', isFinal: false);
      await settle(tester);
      expect(text(tester, 'voice_transcript'), 'gasolina sesenta mil');
    });

    testWidgets('el cronómetro avanza en m:ss', (tester) async {
      await openSheet(tester);
      await startListening(tester);
      expect(text(tester, 'voice_elapsed'), '0:00');

      clock = clock.add(const Duration(seconds: 65));
      await tester.pump(const Duration(milliseconds: 600));

      expect(text(tester, 'voice_elapsed'), '1:05');
    });

    testWidgets('la onda tiene 32 barras que reaccionan al volumen', (
      tester,
    ) async {
      await openSheet(tester);
      await startListening(tester);
      expect(find.byKey(const Key('voice_waveform')), findsOneWidget);
      for (var i = 0; i < 32; i++) {
        expect(find.byKey(Key('voice_wave_bar_$i')), findsOneWidget);
      }
      expect(find.byKey(const Key('voice_wave_bar_32')), findsNothing);

      double lastBar() =>
          tester.getSize(find.byKey(const Key('voice_wave_bar_31'))).height;
      expect(lastBar(), 4); // en silencio, barras mínimas de 4 px

      recognizer.level(1);
      await tester.pump(const Duration(milliseconds: 300));

      expect(lastBar(), greaterThan(20));
      expect(
        tester.getSize(find.byKey(const Key('voice_wave_bar_0'))).width,
        4,
      );
    });

    testWidgets('tocar el botón termina y pasa a revisar', (tester) async {
      await openSheet(tester);
      await startListening(tester);
      recognizer.say('gasolina sesenta mil');
      await tester.pump();

      await tester.tap(find.byKey(const Key('voice_mic_button')));
      await tester.pumpAndSettle();

      expect(recognizer.stopCalls, 1);
      expect(find.text('Revisa y guarda'), findsOneWidget);
    });

    testWidgets('vibra al terminar de escuchar', (tester) async {
      await openSheet(tester);
      await startListening(tester);

      recognizer.say('gasolina 60 mil', isFinal: true);
      await tester.pumpAndSettle();

      expect(haptics, 2); // empezar + terminar
    });

    testWidgets('cancelar vuelve a Listo sin guardar', (tester) async {
      await openSheet(tester);
      await startListening(tester);
      recognizer.say('gasolina 60 mil');
      await tester.pump();

      await tester.tap(find.byKey(const Key('voice_cancel_button')));
      await tester.pumpAndSettle();

      expect(find.text('Toca el micrófono y habla'), findsOneWidget);
      expect(recognizer.isListening, isFalse);
      expect(recognizer.cancelCalls, greaterThanOrEqualTo(1));
      expect(repository.added, isEmpty);
    });

    testWidgets('sin voz muestra "No te escuché bien" y permite reintentar', (
      tester,
    ) async {
      await openSheet(tester);
      await startListening(tester);

      await tester.tap(find.byKey(const Key('voice_mic_button')));
      await tester.pumpAndSettle();

      expect(find.text('No te escuché bien'), findsOneWidget);

      await tester.tap(find.byKey(const Key('voice_retry_button')));
      await settle(tester);

      expect(find.text('Escuchando…'), findsOneWidget);
      expect(recognizer.initializeCalls, 2);
    });
  });

  group('Estado 3: Revisar y guardar', () {
    testWidgets('muestra la frase, tipo, monto y filas editables', (
      tester,
    ) async {
      await openSheet(tester);

      await dictate(tester, 'Gasolina sesenta mil');

      expect(find.text('Revisa y guarda'), findsOneWidget);
      expect(find.text('“Gasolina sesenta mil”'), findsOneWidget);
      expect(find.text('Ingreso'), findsOneWidget);
      expect(find.text('Gasto'), findsOneWidget);
      expect(text(tester, 'voice_amount_text'), '−\$60.000');
      expect(find.text('Combustible'), findsOneWidget);
      expect(find.text('Mazda 3'), findsOneWidget);
      expect(find.text('Hoy'), findsOneWidget);
      expect(find.text('Guardar gasto'), findsOneWidget);
      expect(find.text('Grabar de nuevo'), findsOneWidget);
    });

    testWidgets('el gasto se muestra en rojo con signo menos', (tester) async {
      await openSheet(tester);

      await dictate(tester, 'gasolina 60 mil');

      final amount = tester.widget<Text>(
        find.byKey(const Key('voice_amount_text')),
      );
      expect(amount.style!.color, const Color(0xFFDC2626));
      expect(amount.style!.fontSize, 44);
      expect(amount.style!.fontWeight, FontWeight.w800);
    });

    testWidgets(
      'el ingreso se muestra en verde con signo más y sin categoría',
      (tester) async {
        await openSheet(tester);

        await dictate(tester, 'Ingreso de 150 mil');

        final amount = tester.widget<Text>(
          find.byKey(const Key('voice_amount_text')),
        );
        expect(amount.data, '+\$150.000');
        expect(amount.style!.color, const Color(0xFF047857));
        expect(find.text('Guardar ingreso'), findsOneWidget);
        expect(find.byKey(const Key('voice_row_category')), findsNothing);
      },
    );

    testWidgets('cambiar el tipo actualiza monto, color y botón', (
      tester,
    ) async {
      await openSheet(tester);
      await dictate(tester, 'gasolina 60 mil');

      await tapKey(tester, 'voice_type_income');

      expect(text(tester, 'voice_amount_text'), '+\$60.000');
      expect(find.text('Guardar ingreso'), findsOneWidget);
      expect(find.byKey(const Key('voice_row_category')), findsNothing);

      await tapKey(tester, 'voice_type_expense');

      expect(text(tester, 'voice_amount_text'), '−\$60.000');
      expect(find.text('Guardar gasto'), findsOneWidget);
      expect(find.byKey(const Key('voice_row_category')), findsOneWidget);
    });

    testWidgets('editar el monto a mano', (tester) async {
      await openSheet(tester);
      await dictate(tester, 'gasolina 60 mil');

      await tapKey(tester, 'voice_amount');
      await tester.enterText(
        find.byKey(const Key('voice_amount_field')),
        '75000',
      );
      await tapKey(tester, 'voice_amount_accept');

      expect(text(tester, 'voice_amount_text'), '−\$75.000');
    });

    testWidgets('un monto inválido en el diálogo no se acepta', (tester) async {
      await openSheet(tester);
      await dictate(tester, 'gasolina 60 mil');

      await tapKey(tester, 'voice_amount');
      await tester.enterText(find.byKey(const Key('voice_amount_field')), '0');
      await tapKey(tester, 'voice_amount_accept');

      expect(find.text('Ingresa un valor mayor a cero'), findsOneWidget);
      expect(find.byKey(const Key('voice_amount_field')), findsOneWidget);
    });

    testWidgets('cambiar la categoría con el selector', (tester) async {
      await openSheet(tester);
      await dictate(tester, 'gasolina 60 mil');

      await tapKey(tester, 'voice_row_category');
      await tapKey(tester, 'voice_category_option_maintenance');

      expect(find.text('Mantenimiento'), findsOneWidget);
      expect(find.text('Combustible'), findsNothing);
    });

    testWidgets('cambiar el vehículo con el selector', (tester) async {
      await openSheet(tester);
      await dictate(tester, 'gasolina 60 mil');

      await tapKey(tester, 'voice_row_vehicle');
      await tapKey(tester, 'voice_vehicle_option_c2');

      expect(find.text('Renault Duster'), findsOneWidget);
    });

    testWidgets('el vehículo nombrado en la frase se preselecciona', (
      tester,
    ) async {
      await openSheet(tester);

      await dictate(tester, 'cambio de aceite 120 mil la Duster');

      expect(find.text('Renault Duster'), findsOneWidget);
    });

    testWidgets('cambiar la fecha con el selector', (tester) async {
      await openSheet(tester);
      await dictate(tester, 'gasolina 60 mil');
      expect(find.text('Hoy'), findsOneWidget);

      await tapKey(tester, 'voice_row_date');
      await tester.tap(find.text('9'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();

      expect(find.text('Ayer'), findsOneWidget);
    });

    testWidgets('la fecha dicha se muestra ("ayer")', (tester) async {
      await openSheet(tester);

      await dictate(tester, 'cambio de aceite 120 mil ayer');

      expect(find.text('Ayer'), findsOneWidget);
      expect(find.text('Mantenimiento'), findsOneWidget);
    });

    testWidgets('muestra litros y kilometraje si se dijeron', (tester) async {
      await openSheet(tester);

      await dictate(tester, 'gasolina 60 mil 10 litros 45200 km');

      expect(text(tester, 'voice_extra_details'), '10 L · 45200 km');
    });

    testWidgets('"Grabar de nuevo" vuelve a escuchar y descarta lo anterior', (
      tester,
    ) async {
      await openSheet(tester);
      await dictate(tester, 'gasolina 60 mil');

      await tester.tap(find.byKey(const Key('voice_retry_button')));
      await settle(tester);

      expect(find.text('Escuchando…'), findsOneWidget);
      expect(recognizer.initializeCalls, 2);
      expect(find.text('“gasolina 60 mil”'), findsNothing);
    });

    testWidgets('sin monto no se puede guardar hasta escribirlo', (
      tester,
    ) async {
      await openSheet(tester);

      await dictate(tester, 'gasté en gasolina');

      expect(text(tester, 'voice_amount_text'), r'$0');
      expect(
        find.text('No entendí el monto. Toca para escribirlo.'),
        findsOneWidget,
      );
      expect(saveButton(tester).onPressed, isNull);

      await tapKey(tester, 'voice_amount');
      await tester.enterText(
        find.byKey(const Key('voice_amount_field')),
        '55000',
      );
      await tapKey(tester, 'voice_amount_accept');

      expect(saveButton(tester).onPressed, isNotNull);
    });

    testWidgets('guardar crea el movimiento y cierra con su id', (
      tester,
    ) async {
      await openSheet(tester);
      await dictate(tester, 'gasolina 60 mil');

      await tapKey(tester, 'voice_save_button');

      expect(repository.added, hasLength(1));
      final saved = repository.added.single;
      expect(saved.userId, 'u1');
      expect(saved.carId, 'c1');
      expect(saved.type, TransactionType.expense);
      expect(saved.category, TransactionCategory.fuel);
      expect(saved.amount, 60000);
      expect(closed, isTrue);
      final result = outcome as VoiceEntrySaved;
      expect(result.transactionId, 'tx-1');
      expect(result.type, TransactionType.expense);
      // El micrófono quedó apagado.
      expect(recognizer.isListening, isFalse);
      expect(recognizer.cancelCalls, greaterThanOrEqualTo(1));
    });

    testWidgets('guarda lo corregido: tipo, monto, categoría, vehículo', (
      tester,
    ) async {
      await openSheet(tester);
      await dictate(tester, 'gasolina 60 mil');

      await tapKey(tester, 'voice_type_income');
      await tapKey(tester, 'voice_amount');
      await tester.enterText(
        find.byKey(const Key('voice_amount_field')),
        '150000',
      );
      await tapKey(tester, 'voice_amount_accept');
      await tapKey(tester, 'voice_row_vehicle');
      await tapKey(tester, 'voice_vehicle_option_c2');
      await tapKey(tester, 'voice_save_button');

      final saved = repository.added.single;
      expect(saved.type, TransactionType.income);
      expect(saved.amount, 150000);
      expect(saved.carId, 'c2');
      expect(saved.category, isNull);
      expect((outcome as VoiceEntrySaved).type, TransactionType.income);
    });

    testWidgets('si falla el guardado sigue abierta y se puede reintentar', (
      tester,
    ) async {
      repository.failWith = Exception('sin red');
      await openSheet(tester);
      await dictate(tester, 'gasolina 60 mil');

      await tapKey(tester, 'voice_save_button');

      expect(find.textContaining('Error al guardar'), findsOneWidget);
      expect(closed, isFalse);
      expect(saveButton(tester).onPressed, isNotNull);
      expect(recognizer.isListening, isFalse);
    });

    testWidgets('sin usuario autenticado no guarda', (tester) async {
      await openSheet(tester, currentUserId: () => null);
      await dictate(tester, 'gasolina 60 mil');

      await tapKey(tester, 'voice_save_button');

      expect(find.text('Error: Usuario no autenticado'), findsOneWidget);
      expect(repository.added, isEmpty);
    });

    testWidgets('los botones de acción miden 52 de alto', (tester) async {
      await openSheet(tester);
      await dictate(tester, 'gasolina 60 mil');

      for (final key in ['voice_save_button', 'voice_retry_button']) {
        expect(tester.getSize(find.byKey(Key(key))).height, 52, reason: key);
      }
    });
  });

  group('Errores y permisos', () {
    testWidgets('sin permiso explica por qué y ofrece abrir Ajustes', (
      tester,
    ) async {
      recognizer.initFailure = SpeechFailure.permissionDenied;
      await openSheet(tester);

      await startListening(tester);

      expect(find.text('Necesito tu permiso'), findsOneWidget);
      expect(
        find.textContaining('micrófono y el reconocimiento de voz'),
        findsOneWidget,
      );
      expect(recognizer.isListening, isFalse);

      await tapKey(tester, 'voice_open_settings_button');
      expect(settingsOpened, 1);
    });

    testWidgets('sin conexión ofrece reintentar o registrar a mano', (
      tester,
    ) async {
      recognizer.initFailure = SpeechFailure.network;
      await openSheet(tester);

      await startListening(tester);

      expect(find.text('Sin conexión'), findsOneWidget);
      expect(find.textContaining('necesita internet'), findsOneWidget);
      expect(find.byKey(const Key('voice_retry_button')), findsOneWidget);
      expect(find.byKey(const Key('voice_manual_button')), findsOneWidget);
    });

    testWidgets('un error mientras escucha muestra el problema', (
      tester,
    ) async {
      await openSheet(tester);
      await startListening(tester);

      recognizer.fail(SpeechFailure.network);
      await tester.pumpAndSettle();

      expect(find.text('Sin conexión'), findsOneWidget);
    });

    testWidgets(
      'si no hay reconocimiento disponible solo queda registrar a mano',
      (tester) async {
        recognizer.initFailure = SpeechFailure.unavailable;
        await openSheet(tester);

        await startListening(tester);

        expect(find.text('Voz no disponible'), findsOneWidget);
        expect(find.byKey(const Key('voice_retry_button')), findsNothing);
        expect(find.byKey(const Key('voice_manual_button')), findsOneWidget);
      },
    );

    testWidgets('"Registrar a mano" cierra pidiendo el formulario', (
      tester,
    ) async {
      recognizer.initFailure = SpeechFailure.unavailable;
      await openSheet(tester);
      await startListening(tester);

      await tapKey(tester, 'voice_manual_button');

      expect(closed, isTrue);
      expect(outcome, isA<VoiceEntryManual>());
    });

    testWidgets('tras un fallo se puede reintentar', (tester) async {
      recognizer.initFailure = SpeechFailure.network;
      await openSheet(tester);
      await startListening(tester);

      recognizer.initFailure = null;
      await tester.tap(find.byKey(const Key('voice_retry_button')));
      await settle(tester);

      expect(find.text('Escuchando…'), findsOneWidget);
    });
  });

  testWidgets('cerrar la hoja apaga el micrófono', (tester) async {
    await openSheet(tester);
    await startListening(tester);
    expect(recognizer.isListening, isTrue);

    await tester.tap(find.byKey(const Key('voice_cancel_button')));
    await tester.pumpAndSettle();
    await tapKey(tester, 'voice_close_button');

    expect(recognizer.isListening, isFalse);
    expect(closed, isTrue);
  });
}
