import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:new_my_car_app/models/car.dart';
import 'package:new_my_car_app/models/car_transaction.dart';
import 'package:new_my_car_app/providers/car_provider.dart';
import 'package:new_my_car_app/providers/transaction_provider.dart';
import 'package:new_my_car_app/screens/add_transaction_screen.dart';
import 'package:new_my_car_app/services/transaction_repository.dart';

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

  setUp(() => repository = _FakeRepository());

  Future<void> pumpScreen(
    WidgetTester tester, {
    TransactionType initialType = TransactionType.income,
    String? Function()? currentUserId,
  }) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<CarProvider>(create: (_) => _FakeCarProvider()),
          ChangeNotifierProvider(
            create: (_) => TransactionProvider(repository: repository),
          ),
        ],
        child: MaterialApp(
          home: AddTransactionScreen(
            initialCarId: 'c1',
            initialType: initialType,
            currentUserId: currentUserId ?? () => 'u1',
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
}
