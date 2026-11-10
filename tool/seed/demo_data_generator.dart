import 'dart:math';

import 'package:new_my_car_app/models/alert.dart';
import 'package:new_my_car_app/models/car.dart';
import 'package:new_my_car_app/models/car_transaction.dart';
import 'package:new_my_car_app/models/maintenance_log.dart';
import 'package:new_my_car_app/models/mileage_reading.dart';
import 'package:new_my_car_app/models/trip_log.dart';
import 'package:new_my_car_app/services/alert_templates.dart';

/// Datos de demostración de un usuario: vehículos con historial coherente
/// (odómetro creciente, servicios, combustible, viajes y alertas).
class DemoData {
  final List<Car> cars;
  final List<MileageReading> mileageReadings;
  final List<MaintenanceLog> maintenanceLogs;
  final List<CarTransaction> transactions;
  final List<TripLog> trips;
  final List<Alert> alerts;

  const DemoData({
    required this.cars,
    required this.mileageReadings,
    required this.maintenanceLogs,
    required this.transactions,
    required this.trips,
    required this.alerts,
  });
}

/// Genera datos de demostración sin tocar red ni base de datos.
///
/// Es determinista: con el mismo [seed] y la misma fecha [now] produce lo
/// mismo. Los ids se generan con [newId] (inyectable para tests).
///
/// Los vehículos se escogen para mostrar los distintos estados de las
/// recomendaciones de mantenimiento: al día, próximo, vencido y falta historial.
class DemoDataGenerator {
  /// Placas de los vehículos de demo. Sirven para identificarlos y borrarlos
  /// al volver a ejecutar el script sin tocar los vehículos reales del usuario.
  static const List<String> demoPlates = ['MZD321', 'SPK918', 'RDS452'];

  static const _fuelStations = [
    'Tanqueada Terpel',
    'Tanqueada Primax',
    'Tanqueada Esso',
  ];
  static const _pricePerLiter = 4200.0;

  final String userId;
  final DateTime now;
  final String Function() newId;
  final Random _random;

  DemoDataGenerator({
    required this.userId,
    required this.now,
    required this.newId,
    int seed = 42,
  }) : _random = Random(seed);

  DemoData generate() {
    final cars = <Car>[];
    final readings = <MileageReading>[];
    final logs = <MaintenanceLog>[];
    final transactions = <CarTransaction>[];
    final trips = <TripLog>[];
    final alerts = <Alert>[];

    for (final profile in _profiles) {
      final carId = newId();
      final timeline = _Timeline.build(profile, _random);

      cars.add(
        Car(
          id: carId,
          userId: userId,
          brand: profile.brand,
          model: profile.model,
          year: profile.year,
          plateNumber: profile.plate,
          color: profile.color,
          purchaseDate: _utc(profile.purchasedDaysAgo, 15),
          purchasePrice: profile.purchasePrice,
          notes: profile.notes,
        ),
      );

      readings.addAll(_readings(profile, carId, timeline));
      final carLogs = _maintenanceLogs(profile, carId, timeline);
      logs.addAll(carLogs.logs);
      transactions
        ..addAll(carLogs.expenses)
        ..addAll(_fuel(profile, carId, timeline))
        ..addAll(_otherExpenses(profile, carId, timeline))
        ..addAll(_incomes(profile, carId));
      trips.addAll(_trips(profile, carId, timeline));
      alerts.addAll(_alerts(profile, carId));
    }

    return DemoData(
      cars: cars,
      mileageReadings: readings,
      maintenanceLogs: logs,
      transactions: transactions,
      trips: trips,
      alerts: alerts,
    );
  }

  // --- Odómetro -----------------------------------------------------------

  List<MileageReading> _readings(
    _Profile profile,
    String carId,
    _Timeline timeline,
  ) {
    final result = <MileageReading>[];
    var daysAgo = profile.historyDays;
    while (daysAgo > 1) {
      result.add(
        MileageReading(
          id: newId(),
          userId: userId,
          carId: carId,
          odometerKm: timeline.odometerAt(daysAgo),
          readingDate: _day(daysAgo),
          notes: result.isEmpty ? 'Lectura inicial' : null,
        ),
      );
      daysAgo -= 12 + _random.nextInt(6);
    }
    // Lectura reciente: el odómetro actual del vehículo.
    result.add(
      MileageReading(
        id: newId(),
        userId: userId,
        carId: carId,
        odometerKm: timeline.odometerAt(1),
        readingDate: _day(1),
      ),
    );
    return result;
  }

  // --- Mantenimiento ------------------------------------------------------

  ({List<MaintenanceLog> logs, List<CarTransaction> expenses}) _maintenanceLogs(
    _Profile profile,
    String carId,
    _Timeline timeline,
  ) {
    final logs = <MaintenanceLog>[];
    final expenses = <CarTransaction>[];

    for (final service in profile.services) {
      for (final daysAgo in service.daysAgo) {
        final km = timeline.odometerAt(daysAgo);
        logs.add(
          MaintenanceLog(
            id: newId(),
            userId: userId,
            carId: carId,
            serviceType: service.type,
            odometerKm: km,
            serviceDate: _day(daysAgo),
            notes: service.notes,
          ),
        );
        expenses.add(
          CarTransaction(
            id: newId(),
            userId: userId,
            carId: carId,
            type: TransactionType.expense,
            description: service.label,
            amount: _round(service.cost * (0.92 + _random.nextDouble() * 0.16)),
            date: _utc(daysAgo, 17),
            category: TransactionCategory.maintenance,
            odometerKm: km,
          ),
        );
      }
    }
    return (logs: logs, expenses: expenses);
  }

  // --- Movimientos --------------------------------------------------------

  List<CarTransaction> _fuel(
    _Profile profile,
    String carId,
    _Timeline timeline,
  ) {
    final result = <CarTransaction>[];
    var daysAgo = profile.historyDays - 3;
    double? lastKm;
    while (daysAgo > 1) {
      final km = timeline.odometerAt(daysAgo);
      if (lastKm != null) {
        // Litros coherentes con el rendimiento real (método tanque lleno).
        final liters = _round2(
          (km - lastKm) /
              profile.kmPerLiter *
              (0.94 + _random.nextDouble() * 0.12),
        );
        if (liters > 0) {
          result.add(
            CarTransaction(
              id: newId(),
              userId: userId,
              carId: carId,
              type: TransactionType.expense,
              description: _fuelStations[_random.nextInt(_fuelStations.length)],
              amount: _round(liters * _pricePerLiter),
              date: _utc(daysAgo, 14),
              category: TransactionCategory.fuel,
              liters: liters,
              odometerKm: km,
            ),
          );
        }
      }
      lastKm = km;
      daysAgo -= 9 + _random.nextInt(4);
    }
    return result;
  }

  List<CarTransaction> _otherExpenses(
    _Profile profile,
    String carId,
    _Timeline timeline,
  ) {
    final result = <CarTransaction>[];
    final months = (profile.historyDays / 30).floor();

    CarTransaction expense(String description, double amount, int daysAgo) =>
        CarTransaction(
          id: newId(),
          userId: userId,
          carId: carId,
          type: TransactionType.expense,
          description: description,
          amount: _round(amount),
          date: _utc(daysAgo, 16),
          category: TransactionCategory.other,
        );

    for (var m = 0; m < months; m++) {
      final base = 8 + m * 30;
      if (base >= profile.historyDays) break;
      result.add(expense('Parqueadero mensual', 140000, base));
      if (m.isEven) result.add(expense('Lavado', 35000, base + 5));
      if (m % 3 == 0) {
        result.add(
          expense('Peajes', 18000 + _random.nextInt(9) * 1000, base + 9),
        );
      }
    }
    if (profile.historyDays > 200) {
      result.add(expense('Impuesto vehicular', profile.taxCost, 120));
    }
    return result;
  }

  List<CarTransaction> _incomes(_Profile profile, String carId) {
    if (!profile.earnsIncome) return const [];
    final result = <CarTransaction>[];
    var daysAgo = profile.historyDays - 5;
    while (daysAgo > 0) {
      result.add(
        CarTransaction(
          id: newId(),
          userId: userId,
          carId: carId,
          type: TransactionType.income,
          description: 'Ingresos plataforma de transporte',
          amount: _round(180000 + _random.nextInt(25) * 10000),
          date: _utc(daysAgo, 23),
          notes: 'Liquidación semanal',
        ),
      );
      daysAgo -= 7;
    }
    return result;
  }

  // --- Viajes -------------------------------------------------------------

  List<TripLog> _trips(_Profile profile, String carId, _Timeline timeline) {
    final result = <TripLog>[];
    for (var i = 0; i < profile.tripCount; i++) {
      final daysAgo = 1 + (i * 30 ~/ profile.tripCount) + _random.nextInt(2);
      final distance = _round2(3 + _random.nextDouble() * 42);
      final speed = 22 + _random.nextDouble() * 25; // km/h promedio
      final seconds = (distance / speed * 3600).round();
      final startHour = 12 + _random.nextInt(13); // 7:00–19:00 hora Colombia
      final started = DateTime.utc(
        now.year,
        now.month,
        now.day - daysAgo,
        startHour,
        _random.nextInt(60),
      );
      final startKm = timeline.odometerAt(daysAgo);
      result.add(
        TripLog(
          id: newId(),
          userId: userId,
          carId: carId,
          distanceKm: distance,
          startedAt: started,
          endedAt: started.add(Duration(seconds: seconds)),
          durationSeconds: seconds,
          startOdometerKm: startKm,
          endOdometerKm: _round1(startKm + distance),
        ),
      );
    }
    return result;
  }

  // --- Alertas ------------------------------------------------------------

  List<Alert> _alerts(_Profile profile, String carId) {
    final result = <Alert>[];
    Alert withNotice(Alert alert, int daysBefore) => alert.copyWith(
      id: newId(),
      notificationTime: '08:00',
      notifyDaysBefore: daysBefore,
    );

    for (final spec in profile.alerts) {
      final date = _day(-spec.inDays);
      switch (spec.kind) {
        case _AlertKind.soat:
          result.add(
            withNotice(
              AlertTemplates.createSOAT(
                userId: userId,
                carId: carId,
                startDate: date,
              ),
              3,
            ),
          );
        case _AlertKind.technicalReview:
          result.add(
            withNotice(
              AlertTemplates.createTechnicalReview(
                userId: userId,
                carId: carId,
                startDate: date,
              ),
              3,
            ),
          );
        case _AlertKind.insurance:
          result.add(
            withNotice(
              AlertTemplates.createInsurance(
                userId: userId,
                carId: carId,
                startDate: date,
              ),
              1,
            ),
          );
        case _AlertKind.maintenance:
          result.add(
            withNotice(
              AlertTemplates.createMaintenance(
                userId: userId,
                carId: carId,
                startDate: date,
              ),
              1,
            ),
          );
        case _AlertKind.completedCustom:
          result.add(
            AlertTemplates.createCustom(
              userId: userId,
              carId: carId,
              title: 'Cambiar plumillas',
              description: 'Cambio de plumillas del parabrisas',
              alertDate: date,
            ).copyWith(
              id: newId(),
              isCompleted: true,
              completedAt: _utc(-spec.inDays, 15),
            ),
          );
      }
    }
    return result;
  }

  // --- Fechas y redondeos -------------------------------------------------

  /// Fecha (sin hora) de hace [daysAgo] días; negativo = en el futuro.
  DateTime _day(int daysAgo) =>
      DateTime(now.year, now.month, now.day - daysAgo);

  DateTime _utc(int daysAgo, int hour) =>
      DateTime.utc(now.year, now.month, now.day - daysAgo, hour);

  static double _round(double v) => (v / 100).round() * 100.0;
  static double _round1(double v) => (v * 10).round() / 10;
  static double _round2(double v) => (v * 100).round() / 100;
}

/// Odómetro del vehículo día a día, siempre creciente.
class _Timeline {
  final List<double> _cumulative; // índice = días desde el inicio
  final int _historyDays;

  _Timeline._(this._cumulative, this._historyDays);

  factory _Timeline.build(_Profile profile, Random random) {
    final cumulative = <double>[profile.startKm];
    for (var i = 1; i <= profile.historyDays; i++) {
      // Entre 40% y 160% del promedio diario; nunca retrocede.
      final km = profile.kmPerDay * (0.4 + random.nextDouble() * 1.2);
      cumulative.add(cumulative.last + km);
    }
    return _Timeline._(cumulative, profile.historyDays);
  }

  /// Odómetro (km, 1 decimal) de hace [daysAgo] días.
  double odometerAt(int daysAgo) {
    final index = (_historyDays - daysAgo).clamp(0, _historyDays);
    return (_cumulative[index] * 10).round() / 10;
  }
}

class _Service {
  final String type;
  final String label;
  final double cost;
  final List<int> daysAgo;
  final String? notes;

  const _Service(this.type, this.label, this.cost, this.daysAgo, {this.notes});
}

enum _AlertKind {
  soat,
  technicalReview,
  insurance,
  maintenance,
  completedCustom,
}

class _AlertSpec {
  final _AlertKind kind;

  /// Días hasta la fecha de la alerta; negativo = ya vencida.
  final int inDays;

  const _AlertSpec(this.kind, this.inDays);
}

class _Profile {
  final String brand;
  final String model;
  final int year;
  final String plate;
  final String color;
  final int purchasedDaysAgo;
  final double purchasePrice;
  final String? notes;
  final double startKm;
  final double kmPerDay;
  final double kmPerLiter;
  final int historyDays;
  final double taxCost;
  final bool earnsIncome;
  final int tripCount;
  final List<_Service> services;
  final List<_AlertSpec> alerts;

  const _Profile({
    required this.brand,
    required this.model,
    required this.year,
    required this.plate,
    required this.color,
    required this.purchasedDaysAgo,
    required this.purchasePrice,
    required this.startKm,
    required this.kmPerDay,
    required this.kmPerLiter,
    required this.historyDays,
    required this.taxCost,
    required this.earnsIncome,
    required this.tripCount,
    required this.services,
    required this.alerts,
    this.notes,
  });
}

const List<_Profile> _profiles = [
  // Al día, con un servicio "próximo" y otro con "falta historial".
  _Profile(
    brand: 'Mazda',
    model: '3 Touring',
    year: 2021,
    plate: 'MZD321',
    color: 'Rojo',
    purchasedDaysAgo: 1400,
    purchasePrice: 82000000,
    notes: 'Vehículo de trabajo (plataforma de transporte).',
    startKm: 31000,
    kmPerDay: 45,
    kmPerLiter: 12,
    historyDays: 330,
    taxCost: 960000,
    earnsIncome: true,
    tripCount: 18,
    services: [
      _Service('oil_change', 'Cambio de aceite', 220000, [
        300,
        205,
        110,
        20,
      ], notes: 'Aceite sintético 5W-30 y filtro'),
      _Service('tire_rotation', 'Rotación de llantas', 60000, [250, 60]),
      _Service('air_filter', 'Filtro de aire', 45000, [320, 150]),
      _Service('brake_check', 'Revisión de frenos', 80000, [90]),
    ],
    alerts: [
      _AlertSpec(_AlertKind.soat, 18),
      _AlertSpec(_AlertKind.technicalReview, 75),
      _AlertSpec(_AlertKind.insurance, 140),
      _AlertSpec(_AlertKind.maintenance, 25),
      _AlertSpec(_AlertKind.completedCustom, -12),
    ],
  ),
  // Cambio de aceite vencido y alerta de SOAT vencida.
  _Profile(
    brand: 'Chevrolet',
    model: 'Spark GT',
    year: 2018,
    plate: 'SPK918',
    color: 'Blanco',
    purchasedDaysAgo: 2600,
    purchasePrice: 38000000,
    startKm: 79000,
    kmPerDay: 30,
    kmPerLiter: 14,
    historyDays: 330,
    taxCost: 420000,
    earnsIncome: false,
    tripCount: 8,
    services: [
      _Service('oil_change', 'Cambio de aceite', 150000, [320, 230, 140]),
      _Service('coolant', 'Refrigerante', 90000, [200, 15]),
      _Service('general_maintenance', 'Mantenimiento general', 280000, [150]),
    ],
    alerts: [
      _AlertSpec(_AlertKind.soat, -5),
      _AlertSpec(_AlertKind.technicalReview, 200),
    ],
  ),
  // Vehículo nuevo con poco historial.
  _Profile(
    brand: 'Renault',
    model: 'Duster Intens',
    year: 2023,
    plate: 'RDS452',
    color: 'Gris',
    purchasedDaysAgo: 150,
    purchasePrice: 98000000,
    startKm: 4000,
    kmPerDay: 25,
    kmPerLiter: 11,
    historyDays: 120,
    taxCost: 1100000,
    earnsIncome: false,
    tripCount: 5,
    services: [
      _Service('oil_change', 'Cambio de aceite', 260000, [100]),
    ],
    alerts: [
      _AlertSpec(_AlertKind.soat, 300),
      _AlertSpec(_AlertKind.insurance, 320),
    ],
  ),
];
