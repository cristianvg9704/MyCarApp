import 'package:flutter_test/flutter_test.dart';
import 'package:new_my_car_app/models/car_transaction.dart';
import 'package:new_my_car_app/models/maintenance_log.dart';
import 'package:new_my_car_app/models/maintenance_recommendation.dart';
import 'package:new_my_car_app/models/mileage_reading.dart';
import 'package:new_my_car_app/providers/mileage_provider.dart';
import 'package:new_my_car_app/services/mileage_repository.dart';

class FakeMileageRepository implements MileageRepository {
  @override
  String? currentUserId = 'u1';

  final List<MileageReading> readings = [];
  final List<MaintenanceLog> logs = [];
  final List<CarTransaction> transactions = [];
  bool failOnRead = false;
  bool failOnTransactions = false;

  @override
  Future<List<MileageReading>> getReadings(String carId) async {
    if (failOnRead) throw Exception('read failed');
    return readings.where((r) => r.carId == carId).toList();
  }

  @override
  Future<List<MaintenanceLog>> getMaintenanceLogs(String carId) async =>
      logs.where((l) => l.carId == carId).toList();

  @override
  Future<List<CarTransaction>> getTransactions(String carId) async {
    if (failOnTransactions) throw Exception('tx failed');
    return transactions.where((t) => t.carId == carId).toList();
  }

  @override
  Future<void> addReading(MileageReading reading) async =>
      readings.add(reading);

  @override
  Future<void> addMaintenanceLog(MaintenanceLog log) async => logs.add(log);
}

MileageReading _reading(double km, DateTime date) => MileageReading(
  userId: 'u1',
  carId: 'c1',
  odometerKm: km,
  readingDate: date,
);

MaintenanceLog _log(String type, double km, DateTime date) => MaintenanceLog(
  userId: 'u1',
  carId: 'c1',
  serviceType: type,
  odometerKm: km,
  serviceDate: date,
);

void main() {
  late FakeMileageRepository repo;
  late MileageProvider provider;
  final now = DateTime(2025, 6, 1);

  setUp(() {
    repo = FakeMileageRepository();
    provider = MileageProvider(repository: repo, clock: () => now);
  });

  test('without data there are no recommendations nor odometer', () async {
    await provider.loadForCar('c1');

    expect(provider.currentOdometerKm, isNull);
    expect(provider.recommendations, isEmpty);
    expect(provider.insights.hasAnyData, isFalse);
    expect(provider.errorMessage, isNull);
  });

  test('derives recommendations and usage from the owner history', () async {
    repo.readings.addAll([
      _reading(10000, DateTime(2025, 1, 1)),
      _reading(16000, DateTime(2025, 5, 31)),
    ]);
    repo.logs.addAll([
      _log('oil_change', 10000, DateTime(2025, 1, 1)),
      _log('oil_change', 15000, DateTime(2025, 4, 1)),
      _log('brake_check', 12000, DateTime(2025, 2, 1)),
    ]);
    repo.transactions.add(
      CarTransaction(
        userId: 'u1',
        carId: 'c1',
        type: TransactionType.expense,
        category: TransactionCategory.fuel,
        description: 'Gasolina',
        amount: 100000,
        date: DateTime(2025, 5, 31),
        liters: 30,
        odometerKm: 16100,
      ),
    );

    await provider.loadForCar('c1');

    expect(provider.currentOdometerKm, 16100);
    expect(provider.insights.kmPerDay, isNotNull);
    final oil = provider.recommendations.firstWhere(
      (r) => r.serviceType == 'oil_change',
    );
    expect(oil.intervalKm, 5000);
    expect(oil.kmSinceService, 1100);
    final brakes = provider.recommendations.firstWhere(
      (r) => r.serviceType == 'brake_check',
    );
    expect(brakes.status, MaintenanceStatus.needsHistory);
  });

  test('a failing transactions query does not block the rest', () async {
    repo.readings.add(_reading(10000, DateTime(2025, 1, 1)));
    repo.failOnTransactions = true;

    await provider.loadForCar('c1');

    expect(provider.errorMessage, isNull);
    expect(provider.currentOdometerKm, 10000);
  });

  test('exposes the error when readings fail to load', () async {
    repo.failOnRead = true;
    await provider.loadForCar('c1');
    expect(provider.errorMessage, isNotNull);
    expect(provider.isLoading, isFalse);
  });

  test('readings are exposed newest first', () async {
    repo.readings.addAll([
      _reading(10000, DateTime(2025, 1, 1)),
      _reading(12000, DateTime(2025, 3, 1)),
    ]);
    await provider.loadForCar('c1');
    expect(provider.readings.first.odometerKm, 12000);
  });

  test('addMileageReading stores and reloads', () async {
    final ok = await provider.addMileageReading(
      carId: 'c1',
      odometerKm: 5000,
      readingDate: DateTime(2025, 5, 1),
    );

    expect(ok, isTrue);
    expect(repo.readings, hasLength(1));
    expect(provider.currentOdometerKm, 5000);
  });

  test('addMileageReading rejects an odometer lower than the known one',
      () async {
    repo.readings.add(_reading(8000, DateTime(2025, 1, 1)));
    await provider.loadForCar('c1');

    final ok = await provider.addMileageReading(
      carId: 'c1',
      odometerKm: 7000,
      readingDate: DateTime(2025, 5, 1),
    );

    expect(ok, isFalse);
    expect(provider.errorMessage, contains('8000'));
    expect(repo.readings, hasLength(1));
  });

  test('addMaintenanceLog needs a signed in user', () async {
    repo.currentUserId = null;
    final ok = await provider.addMaintenanceLog(
      carId: 'c1',
      serviceType: 'oil_change',
      odometerKm: 1000,
    );
    expect(ok, isFalse);
    expect(repo.logs, isEmpty);
  });

  test('two logs of the same service create a derived interval', () async {
    await provider.addMaintenanceLog(
      carId: 'c1',
      serviceType: 'oil_change',
      odometerKm: 10000,
      serviceDate: DateTime(2025, 1, 1),
    );
    expect(
      provider.recommendations.single.status,
      MaintenanceStatus.needsHistory,
    );

    await provider.markMaintenanceDone(
      carId: 'c1',
      serviceType: 'oil_change',
      odometerKm: 15000,
    );

    final rec = provider.recommendations.single;
    expect(rec.recordCount, 2);
    expect(rec.intervalKm, 5000);
    expect(rec.lastServiceDate, DateTime(2025, 6, 1)); // injected clock
  });
}
