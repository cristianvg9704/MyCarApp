import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:new_my_car_app/models/car.dart';
import 'package:new_my_car_app/models/car_transaction.dart';
import 'package:new_my_car_app/providers/car_provider.dart';
import 'package:new_my_car_app/providers/transaction_provider.dart';
import 'package:new_my_car_app/services/speech_recognizer.dart';
import 'package:new_my_car_app/services/transaction_repository.dart';
import 'package:new_my_car_app/utils/transaction_modal_helper.dart';

import '../helpers/fake_speech_recognizer.dart';

class _FakeCarProvider extends CarProvider {
  int loads = 0;

  @override
  List<Car> get cars => [
    Car(id: 'c1', userId: 'u1', brand: 'Mazda', model: '3', year: 2021),
  ];

  @override
  bool get isLoading => false;

  @override
  Future<void> loadCars() async => loads++;
}

class _FakeRepository implements TransactionRepository {
  final List<CarTransaction> added = [];
  final List<String> deleted = [];
  bool failDelete = false;

  @override
  Future<String> add(CarTransaction transaction) async {
    added.add(transaction);
    return 'tx-${added.length}';
  }

  @override
  Future<List<CarTransaction>> getByCar(String carId) async => added;

  @override
  Future<void> update(CarTransaction transaction) async {}

  @override
  Future<void> delete(String id) async {
    if (failDelete) throw Exception('sin red');
    deleted.add(id);
  }
}

void main() {
  late _FakeRepository repository;
  late _FakeCarProvider cars;
  late FakeSpeechRecognizer recognizer;
  late int changes;
  bool? result;

  setUp(() {
    repository = _FakeRepository();
    cars = _FakeCarProvider();
    recognizer = FakeSpeechRecognizer();
    changes = 0;
    result = null;
  });

  Future<void> openFromHost(WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<CarProvider>.value(value: cars),
          ChangeNotifierProvider(
            create: (_) => TransactionProvider(repository: repository),
          ),
        ],
        child: MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: ElevatedButton(
                onPressed: () async {
                  result =
                      await TransactionModalHelper.showVoiceTransactionSheet(
                        context,
                        carId: 'c1',
                        onChanged: () => changes++,
                        speechRecognizer: recognizer,
                        currentUserId: () => 'u1',
                      );
                },
                child: const Text('voz'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('voz'));
    await tester.pumpAndSettle();
  }

  Future<void> dictateAndSave(WidgetTester tester, String phrase) async {
    await tester.tap(find.byKey(const Key('voice_mic_button')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    recognizer.say(phrase, isFinal: true);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('voice_save_button')));
    await tester.pumpAndSettle();
  }

  testWidgets('guardar un gasto cierra la hoja, avisa y refresca', (
    tester,
  ) async {
    await openFromHost(tester);

    await dictateAndSave(tester, 'gasolina 60 mil');

    expect(repository.added, hasLength(1));
    expect(result, isTrue);
    expect(find.byKey(const Key('voice_mic_button')), findsNothing);
    expect(find.text('Gasto guardado'), findsOneWidget);
    expect(find.text('Deshacer'), findsOneWidget);
    expect(changes, greaterThanOrEqualTo(1));
    expect(cars.loads, greaterThanOrEqualTo(1));
  });

  testWidgets('un ingreso dice "Ingreso guardado"', (tester) async {
    await openFromHost(tester);

    await dictateAndSave(tester, 'ingreso de 150 mil');

    expect(find.text('Ingreso guardado'), findsOneWidget);
  });

  testWidgets('Deshacer borra el movimiento y vuelve a refrescar', (
    tester,
  ) async {
    await openFromHost(tester);
    await dictateAndSave(tester, 'gasolina 60 mil');
    final changesAfterSave = changes;
    final loadsAfterSave = cars.loads;

    await tester.tap(find.text('Deshacer'));
    await tester.pumpAndSettle();

    expect(repository.deleted, ['tx-1']);
    expect(changes, greaterThan(changesAfterSave));
    expect(cars.loads, greaterThan(loadsAfterSave));
  });

  testWidgets('si no se puede deshacer lo avisa', (tester) async {
    await openFromHost(tester);
    await dictateAndSave(tester, 'gasolina 60 mil');
    repository.failDelete = true;

    await tester.tap(find.text('Deshacer'));
    await tester.pumpAndSettle();

    expect(find.text('No se pudo deshacer'), findsOneWidget);
  });

  testWidgets('cerrar sin guardar no avisa ni refresca', (tester) async {
    await openFromHost(tester);

    await tester.tap(find.byKey(const Key('voice_close_button')));
    await tester.pumpAndSettle();

    expect(result, isNull);
    expect(find.text('Gasto guardado'), findsNothing);
    expect(changes, 0);
  });

  testWidgets('"Registrar a mano" abre el formulario completo', (tester) async {
    recognizer.initFailure = SpeechFailure.unavailable;
    await openFromHost(tester);
    await tester.tap(find.byKey(const Key('voice_mic_button')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('voice_manual_button')));
    await tester.pumpAndSettle();

    expect(find.text('Registrar Movimiento'), findsOneWidget);
    expect(find.byKey(const Key('voice_mic_button')), findsNothing);
  });
}
