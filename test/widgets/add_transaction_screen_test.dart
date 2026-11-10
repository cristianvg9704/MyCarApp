import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:new_my_car_app/models/car.dart';
import 'package:new_my_car_app/models/car_transaction.dart';
import 'package:new_my_car_app/providers/car_provider.dart';
import 'package:new_my_car_app/providers/transaction_provider.dart';
import 'package:new_my_car_app/screens/add_transaction_screen.dart';
import 'package:new_my_car_app/services/speech_recognizer.dart';
import 'package:new_my_car_app/services/transaction_repository.dart';

import '../helpers/fake_speech_recognizer.dart';

class _FakeCarProvider extends CarProvider {
  @override
  List<Car> get cars => [
    Car(id: 'c1', userId: 'u1', brand: 'Toyota', model: 'Corolla', year: 2020),
  ];

  @override
  bool get isLoading => false;

  @override
  Future<void> loadCars() async {}
}

class _FakeRepository implements TransactionRepository {
  final List<CarTransaction> added = [];

  @override
  Future<String> add(CarTransaction transaction) async {
    added.add(transaction);
    return 'id';
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

  setUp(() {
    repository = _FakeRepository();
    recognizer = FakeSpeechRecognizer();
  });

  Future<void> pumpScreen(
    WidgetTester tester, {
    TransactionType initialType = TransactionType.income,
    String? Function()? currentUserId,
    bool startWithVoice = false,
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
          home: AddTransactionScreen(
            initialCarId: 'c1',
            initialType: initialType,
            currentUserId: currentUserId ?? () => 'u1',
            speechRecognizer: recognizer,
            startWithVoice: startWithVoice,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Finder field(String label) => find.widgetWithText(TextFormField, label);

  testWidgets('starts as an income without expense-only fields', (
    tester,
  ) async {
    await pumpScreen(tester);

    expect(find.text('Guardar Ingreso'), findsOneWidget);
    expect(find.byType(ChoiceChip), findsNothing);
    expect(field('Litros'), findsNothing);
    expect(field('Kilometraje'), findsNothing);
  });

  testWidgets('switching to expense shows categories and fuel fields', (
    tester,
  ) async {
    await pumpScreen(tester);

    await tester.tap(find.text('Egreso'));
    await tester.pumpAndSettle();

    expect(find.text('Guardar Egreso'), findsOneWidget);
    expect(find.widgetWithText(ChoiceChip, 'Combustible'), findsOneWidget);
    expect(find.widgetWithText(ChoiceChip, 'Mantenimiento'), findsOneWidget);
    expect(find.widgetWithText(ChoiceChip, 'Otros'), findsOneWidget);
    expect(field('Litros'), findsOneWidget);
    expect(field('Kilometraje'), findsOneWidget);
  });

  testWidgets('maintenance has odometer but no liters; other has neither', (
    tester,
  ) async {
    await pumpScreen(tester, initialType: TransactionType.expense);

    await tester.tap(find.widgetWithText(ChoiceChip, 'Mantenimiento'));
    await tester.pumpAndSettle();
    expect(field('Litros'), findsNothing);
    expect(field('Kilometraje'), findsOneWidget);

    await tester.tap(find.widgetWithText(ChoiceChip, 'Otros'));
    await tester.pumpAndSettle();
    expect(field('Litros'), findsNothing);
    expect(field('Kilometraje'), findsNothing);
  });

  testWidgets('income requires description and amount', (tester) async {
    await pumpScreen(tester);

    await tester.tap(find.text('Guardar Ingreso'));
    await tester.pumpAndSettle();

    expect(find.text('Por favor ingresa una descripción'), findsOneWidget);
    expect(find.text('Por favor ingresa el monto'), findsOneWidget);
    expect(repository.added, isEmpty);
  });

  testWidgets('rejects zero and non numeric amounts', (tester) async {
    await pumpScreen(tester);
    await tester.enterText(field('Descripción *'), 'Viaje');

    await tester.enterText(field('Monto *'), '0');
    await tester.tap(find.text('Guardar Ingreso'));
    await tester.pumpAndSettle();
    expect(find.text('Ingresa un valor válido mayor a cero'), findsOneWidget);

    await tester.enterText(field('Monto *'), 'abc');
    await tester.tap(find.text('Guardar Ingreso'));
    await tester.pumpAndSettle();
    expect(find.text('Ingresa un valor válido mayor a cero'), findsOneWidget);
    expect(repository.added, isEmpty);
  });

  testWidgets('saves an income parsing a Colombian formatted amount', (
    tester,
  ) async {
    await pumpScreen(tester);

    await tester.enterText(field('Descripción *'), 'Viaje aeropuerto');
    await tester.enterText(field('Monto *'), '50.000');
    await tester.tap(find.text('Guardar Ingreso'));
    await tester.pumpAndSettle();

    expect(repository.added, hasLength(1));
    final saved = repository.added.single;
    expect(saved.type, TransactionType.income);
    expect(saved.carId, 'c1');
    expect(saved.userId, 'u1');
    expect(saved.description, 'Viaje aeropuerto');
    expect(saved.amount, 50000);
    expect(saved.category, isNull);
    expect(saved.liters, isNull);
  });

  testWidgets('saves a fuel expense with liters and odometer', (tester) async {
    await pumpScreen(tester, initialType: TransactionType.expense);

    await tester.enterText(field('Descripción'), 'Terpel');
    await tester.enterText(field('Monto *'), '80000');
    await tester.enterText(field('Litros'), '10,5');
    await tester.enterText(field('Kilometraje'), '45200');
    await tester.tap(find.text('Guardar Egreso'));
    await tester.pumpAndSettle();

    final saved = repository.added.single;
    expect(saved.type, TransactionType.expense);
    expect(saved.category, TransactionCategory.fuel);
    expect(saved.amount, 80000);
    expect(saved.liters, 10.5);
    expect(saved.odometerKm, 45200);
  });

  testWidgets('expense description defaults to the category label', (
    tester,
  ) async {
    await pumpScreen(tester, initialType: TransactionType.expense);

    await tester.tap(find.widgetWithText(ChoiceChip, 'Mantenimiento'));
    await tester.pumpAndSettle();
    await tester.enterText(field('Monto *'), '120000');
    await tester.tap(find.text('Guardar Egreso'));
    await tester.pumpAndSettle();

    final saved = repository.added.single;
    expect(saved.description, 'Mantenimiento');
    expect(saved.category, TransactionCategory.maintenance);
    expect(saved.liters, isNull);
  });

  testWidgets('does not keep fuel data when the category changes', (
    tester,
  ) async {
    await pumpScreen(tester, initialType: TransactionType.expense);

    await tester.enterText(field('Litros'), '10');
    await tester.tap(find.widgetWithText(ChoiceChip, 'Otros'));
    await tester.pumpAndSettle();
    await tester.enterText(field('Monto *'), '5000');
    await tester.tap(find.text('Guardar Egreso'));
    await tester.pumpAndSettle();

    final saved = repository.added.single;
    expect(saved.category, TransactionCategory.other);
    expect(saved.liters, isNull);
    expect(saved.odometerKm, isNull);
  });

  testWidgets('shows an error and saves nothing when not authenticated', (
    tester,
  ) async {
    await pumpScreen(tester, currentUserId: () => null);

    await tester.enterText(field('Descripción *'), 'Viaje');
    await tester.enterText(field('Monto *'), '1000');
    await tester.tap(find.text('Guardar Ingreso'));
    await tester.pumpAndSettle();

    expect(find.text('Error: Usuario no autenticado'), findsOneWidget);
    expect(repository.added, isEmpty);
  });

  group('voice input', () {
    Future<void> tapVoice(WidgetTester tester) async {
      await tester.tap(find.text('Registrar por voz'));
      await tester.pumpAndSettle();
    }

    String formatted(DateTime date) => DateFormat('dd/MM/yyyy').format(date);

    testWidgets('shows a hint and a mic button before listening', (
      tester,
    ) async {
      await pumpScreen(tester);

      expect(find.text('Registrar por voz'), findsOneWidget);
      expect(find.textContaining('gasté cincuenta mil'), findsOneWidget);
      expect(recognizer.initializeCalls, 0);
    });

    testWidgets('tapping the mic starts listening', (tester) async {
      await pumpScreen(tester);

      await tapVoice(tester);

      expect(recognizer.initializeCalls, 1);
      expect(recognizer.isListening, isTrue);
      expect(find.text('Escuchando… toca para terminar'), findsOneWidget);
    });

    testWidgets('shows the live transcript while listening', (tester) async {
      await pumpScreen(tester);
      await tapVoice(tester);

      recognizer.say('gasté cincuenta');
      await tester.pump();

      expect(find.text('“gasté cincuenta”'), findsOneWidget);
    });

    testWidgets('fills the form from a fuel expense', (tester) async {
      await pumpScreen(tester);
      await tapVoice(tester);

      recognizer.say('gasté cincuenta mil en gasolina ayer', isFinal: true);
      await tester.pumpAndSettle();

      final yesterday = DateTime.now().subtract(const Duration(days: 1));
      expect(find.text('Guardar Egreso'), findsOneWidget);
      expect(
        tester
            .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'Combustible'))
            .selected,
        isTrue,
      );
      expect(
        tester.widget<TextFormField>(field('Monto *')).controller!.text,
        '50000',
      );
      expect(
        tester.widget<TextFormField>(field('Descripción')).controller!.text,
        'Combustible',
      );
      expect(find.text(formatted(yesterday)), findsOneWidget);
      expect(find.text('Escuchando… toca para terminar'), findsNothing);
    });

    testWidgets('the voice result is saved after the user confirms', (
      tester,
    ) async {
      await pumpScreen(tester);
      await tapVoice(tester);
      recognizer.say(
        'ayer tanqueé diez litros de gasolina por cincuenta mil con 45200 kilómetros',
        isFinal: true,
      );
      await tester.pumpAndSettle();

      expect(repository.added, isEmpty);
      await tester.tap(find.text('Guardar Egreso'));
      await tester.pumpAndSettle();

      final saved = repository.added.single;
      expect(saved.carId, 'c1');
      expect(saved.type, TransactionType.expense);
      expect(saved.category, TransactionCategory.fuel);
      expect(saved.amount, 50000);
      expect(saved.liters, 10);
      expect(saved.odometerKm, 45200);
      final yesterday = DateTime.now().subtract(const Duration(days: 1));
      expect(saved.date.year, yesterday.year);
      expect(saved.date.month, yesterday.month);
      expect(saved.date.day, yesterday.day);
    });

    testWidgets('fills the form from an income', (tester) async {
      await pumpScreen(tester, initialType: TransactionType.expense);
      await tapVoice(tester);

      recognizer.say(
        'me pagaron ciento veinte mil por una carrera',
        isFinal: true,
      );
      await tester.pumpAndSettle();

      expect(find.text('Guardar Ingreso'), findsOneWidget);
      expect(find.byType(ChoiceChip), findsNothing);
      expect(
        tester.widget<TextFormField>(field('Monto *')).controller!.text,
        '120000',
      );
      expect(
        tester.widget<TextFormField>(field('Descripción *')).controller!.text,
        'Me pagaron ciento veinte mil por una carrera',
      );
    });

    testWidgets('converts gallons to liters with at most 2 decimals', (
      tester,
    ) async {
      await pumpScreen(tester);
      await tapVoice(tester);

      recognizer.say('tanqueé 2 galones por 30 mil', isFinal: true);
      await tester.pumpAndSettle();

      expect(
        tester.widget<TextFormField>(field('Litros')).controller!.text,
        '7.57',
      );
    });

    testWidgets('warns when the amount was not understood', (tester) async {
      await pumpScreen(tester);
      await tapVoice(tester);

      recognizer.say('tanqueé la moto', isFinal: true);
      await tester.pumpAndSettle();

      expect(
        find.text('No entendí el monto. Ingrésalo manualmente.'),
        findsOneWidget,
      );
      expect(
        tester.widget<TextFormField>(field('Monto *')).controller!.text,
        isEmpty,
      );
    });

    testWidgets('an empty result asks to try again', (tester) async {
      await pumpScreen(tester);
      await tapVoice(tester);

      recognizer.say('', isFinal: true);
      await tester.pumpAndSettle();

      expect(find.text('No te escuché. Intenta de nuevo.'), findsOneWidget);
    });

    testWidgets('tapping again stops listening and applies the result', (
      tester,
    ) async {
      await pumpScreen(tester);
      await tapVoice(tester);
      recognizer.say('gasté 15 mil');
      await tester.pump();

      await tester.tap(find.text('Escuchando… toca para terminar'));
      await tester.pumpAndSettle();

      expect(recognizer.stopCalls, 1);
      expect(
        tester.widget<TextFormField>(field('Monto *')).controller!.text,
        '15000',
      );
    });

    testWidgets('explains a denied permission and does not listen', (
      tester,
    ) async {
      recognizer.initFailure = SpeechFailure.permissionDenied;
      await pumpScreen(tester);

      await tapVoice(tester);

      expect(find.textContaining('Activa el micrófono'), findsOneWidget);
      expect(recognizer.isListening, isFalse);
      expect(find.text('Registrar por voz'), findsOneWidget);
    });

    testWidgets('explains when speech recognition is unavailable', (
      tester,
    ) async {
      recognizer.initFailure = SpeechFailure.unavailable;
      await pumpScreen(tester);

      await tapVoice(tester);

      expect(
        find.text(
          'Este dispositivo no tiene reconocimiento de voz disponible.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('an error while listening stops and reports it', (
      tester,
    ) async {
      await pumpScreen(tester);
      await tapVoice(tester);

      recognizer.fail(SpeechFailure.failed);
      await tester.pumpAndSettle();

      expect(
        find.text('No se pudo reconocer la voz. Intenta de nuevo.'),
        findsOneWidget,
      );
      expect(find.text('Registrar por voz'), findsOneWidget);
    });

    testWidgets('startWithVoice begins listening automatically', (
      tester,
    ) async {
      await pumpScreen(tester, startWithVoice: true);

      expect(recognizer.initializeCalls, 1);
      expect(recognizer.isListening, isTrue);
    });

    testWidgets('saving while still listening turns the microphone off', (
      tester,
    ) async {
      await pumpScreen(tester);
      await tapVoice(tester);
      expect(recognizer.isListening, isTrue);

      await tester.enterText(field('Descripción *'), 'Viaje');
      await tester.enterText(field('Monto *'), '50000');
      await tester.tap(find.text('Guardar Ingreso'));
      await tester.pumpAndSettle();

      expect(repository.added, hasLength(1));
      expect(recognizer.cancelCalls, greaterThanOrEqualTo(1));
      expect(recognizer.isListening, isFalse);
      // La interfaz ya no aparenta estar escuchando.
      expect(find.text('Escuchando… toca para terminar'), findsNothing);
      expect(find.text('Registrar por voz'), findsOneWidget);
    });

    testWidgets('leaving the screen cancels the recognizer', (tester) async {
      await pumpScreen(tester);
      await tapVoice(tester);

      await tester.pumpWidget(const SizedBox());

      expect(recognizer.cancelCalls, 1);
    });
  });
}
