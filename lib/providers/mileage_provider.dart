import 'package:flutter/material.dart';
import '../models/car_transaction.dart';
import '../models/maintenance_log.dart';
import '../models/maintenance_recommendation.dart';
import '../models/mileage_reading.dart';
import '../services/maintenance_recommendation_service.dart';
import '../services/mileage_repository.dart';
import '../services/usage_analytics.dart';

class MileageProvider extends ChangeNotifier {
  final MileageRepository _repository;
  final DateTime Function() _clock;

  MileageProvider({MileageRepository? repository, DateTime Function()? clock})
    : _repository = repository ?? SupabaseMileageRepository(),
      _clock = clock ?? DateTime.now;

  List<MileageReading> _readings = [];
  List<MaintenanceLog> _maintenanceLogs = [];
  List<CarTransaction> _transactions = [];
  List<MaintenanceRecommendation> _recommendations = [];
  UsageInsights _insights = UsageInsights.empty;
  bool _isLoading = false;
  String? _errorMessage;

  /// Lecturas del odómetro, la más reciente primero.
  List<MileageReading> get readings => _readings;
  List<MaintenanceLog> get maintenanceLogs => _maintenanceLogs;
  List<MaintenanceRecommendation> get recommendations => _recommendations;
  UsageInsights get insights => _insights;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  /// Último odómetro conocido, combinando lecturas, servicios y movimientos
  /// de combustible/mantenimiento con odómetro.
  double? get currentOdometerKm => _insights.currentOdometerKm;

  double get trackedKm =>
      MaintenanceRecommendationService.calculateTrackedKm(_readings);

  Future<void> loadForCar(String carId) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final readings = await _repository.getReadings(carId);
      _readings = List.of(readings)
        ..sort((a, b) => b.readingDate.compareTo(a.readingDate));
      _maintenanceLogs = await _repository.getMaintenanceLogs(carId);
      try {
        _transactions = await _repository.getTransactions(carId);
      } catch (e) {
        // Los movimientos solo enriquecen las métricas; no bloquean la carga.
        _transactions = [];
        debugPrint('Error loading transactions for mileage insights: $e');
      }
      _recompute();
    } catch (e) {
      _errorMessage = e.toString();
      debugPrint('Error loading mileage data: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void _recompute() {
    _insights = UsageAnalytics.compute(
      readings: _readings,
      maintenanceLogs: _maintenanceLogs,
      transactions: _transactions,
    );

    final current = _insights.currentOdometerKm;
    if (current == null) {
      _recommendations = [];
      return;
    }

    _recommendations = MaintenanceRecommendationService.buildRecommendations(
      currentOdometerKm: current,
      maintenanceLogs: _maintenanceLogs,
      now: _clock(),
      kmPerDay: _insights.kmPerDay,
    );
  }

  Future<bool> addMileageReading({
    required String carId,
    required double odometerKm,
    required DateTime readingDate,
    String? notes,
  }) async {
    final userId = _repository.currentUserId;
    if (userId == null) return false;

    final current = currentOdometerKm;
    if (current != null && odometerKm < current) {
      _errorMessage =
          'El odómetro no puede ser menor a la última lectura (${current.toStringAsFixed(0)} km)';
      notifyListeners();
      return false;
    }

    return _write(carId, () {
      return _repository.addReading(
        MileageReading(
          userId: userId,
          carId: carId,
          odometerKm: odometerKm,
          readingDate: readingDate,
          notes: notes,
        ),
      );
    });
  }

  /// Registra que se hizo un servicio de [serviceType] en [odometerKm].
  /// Cada registro alimenta el intervalo propio de ese servicio.
  Future<bool> addMaintenanceLog({
    required String carId,
    required String serviceType,
    required double odometerKm,
    DateTime? serviceDate,
    String? notes,
  }) async {
    final userId = _repository.currentUserId;
    if (userId == null) return false;

    return _write(carId, () {
      return _repository.addMaintenanceLog(
        MaintenanceLog(
          userId: userId,
          carId: carId,
          serviceType: serviceType,
          odometerKm: odometerKm,
          serviceDate: serviceDate ?? _clock(),
          notes: notes,
        ),
      );
    });
  }

  Future<bool> markMaintenanceDone({
    required String carId,
    required String serviceType,
    required double odometerKm,
    String? notes,
  }) => addMaintenanceLog(
    carId: carId,
    serviceType: serviceType,
    odometerKm: odometerKm,
    notes: notes,
  );

  Future<bool> _write(String carId, Future<void> Function() write) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await write();
      await loadForCar(carId);
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }
}
