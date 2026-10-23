import 'package:flutter_test/flutter_test.dart';
import 'package:new_my_car_app/models/car_transaction.dart';
import 'package:new_my_car_app/providers/transaction_provider.dart';
import 'package:new_my_car_app/services/transaction_repository.dart';

class FakeTransactionRepository implements TransactionRepository {
  final List<CarTransaction> stored = [];
  bool failOnWrite = false;
  bool failOnRead = false;

  @override
  Future<List<CarTransaction>> getByCar(String carId) async {
    if (failOnRead) throw Exception('read failed');
    return stored.where((t) => t.carId == carId).toList();
  }

  @override
  Future<String> add(CarTransaction transaction) async {
    if (failOnWrite) throw Exception('write failed');
    stored.add(transaction);
    return 'id-${stored.length}';
  }

  @override
  Future<void> update(CarTransaction transaction) async {
    if (failOnWrite) throw Exception('write failed');
  }

  @override
  Future<void> delete(String id) async {
    if (failOnWrite) throw Exception('write failed');
    stored.removeWhere((t) => t.id == id);
  }
}

CarTransaction _tx(String carId, {String? id, double amount = 100}) =>
    CarTransaction(
      id: id,
      userId: 'u1',
      carId: carId,
      description: 'x',
      amount: amount,
      date: DateTime(2026, 10, 1),
    );

void main() {
  late FakeTransactionRepository repository;
  late TransactionProvider provider;

  setUp(() {
    repository = FakeTransactionRepository();
    provider = TransactionProvider(repository: repository);
  });

  test('starts empty and not loading', () {
    expect(provider.transactions, isEmpty);
    expect(provider.isLoading, isFalse);
    expect(provider.selectedCarId, isNull);
  });

  test('loadByCar loads only the selected car and toggles isLoading', () async {
    repository.stored.addAll([_tx('c1'), _tx('c2')]);
    final states = <bool>[];
    provider.addListener(() => states.add(provider.isLoading));

    await provider.loadByCar('c1');

    expect(states, [true, false]);
    expect(provider.selectedCarId, 'c1');
    expect(provider.transactions, hasLength(1));
    expect(provider.transactions.single.carId, 'c1');
  });

  test('loadByCar recovers when the repository fails', () async {
    repository.failOnRead = true;

    await provider.loadByCar('c1');

    expect(provider.isLoading, isFalse);
    expect(provider.transactions, isEmpty);
  });

  test('add stores the transaction and reloads the selected car', () async {
    await provider.loadByCar('c1');

    await provider.add(_tx('c1'));

    expect(repository.stored, hasLength(1));
    expect(provider.transactions, hasLength(1));
  });

  test('add without a selected car writes but does not load', () async {
    await provider.add(_tx('c1'));

    expect(repository.stored, hasLength(1));
    expect(provider.transactions, isEmpty);
  });

  test('add rethrows repository errors', () async {
    repository.failOnWrite = true;

    expect(() => provider.add(_tx('c1')), throwsException);
  });

  test('delete removes the transaction and reloads', () async {
    repository.stored.add(_tx('c1', id: 'a'));
    await provider.loadByCar('c1');
    expect(provider.transactions, hasLength(1));

    await provider.delete('a');

    expect(provider.transactions, isEmpty);
  });
}
