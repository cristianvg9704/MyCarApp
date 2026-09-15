import 'package:flutter/material.dart';
import '../models/maintenance_log.dart';
import '../models/maintenance_recommendation.dart';
import '../models/mileage_reading.dart';
import '../services/database_helper.dart';
import '../services/maintenance_recommendation_service.dart';
import '../config/supabase_config.dart';

class MileageProvider extends ChangeNotifier {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  List<MileageReading> _readings = [];
  List<MaintenanceLog> _maintenanceLogs = [];
  List<MaintenanceRecommendation> _recommendations = [];
  bool _isLoading = false;
  String? _errorMessage;
  String? _loadedCarId;

  List<MileageReading> get readings => _readings;
  List<MaintenanceLog> get maintenanceLogs => _maintenanceLogs;
  List<MaintenanceRecommendation> get recommendations => _recommendations;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  double? get currentOdometerKm =>
      _readings.isEmpty ? null : _readings.first.odometerKm;

  double get trackedKm =>
      MaintenanceRecommendationService.calculateTrackedKm(_readings);

  Future<void> loadForCar(String carId, {DateTime? baselineDate}) async {
    if (_loadedCarId == carId && _readings.isNotEmpty && !_isLoading) {
      _refreshRecommendations(baselineDate);
      return;
    }

    _isLoading = true;
    _errorMessage = null;
    _loadedCarId = carId;
    notifyListeners();

    try {
      _readings = await _dbHelper.getMileageReadingsByCar(carId);
      _maintenanceLogs = await _dbHelper.getMaintenanceLogsByCar(carId);
      _refreshRecommendations(baselineDate);
    } catch (e) {
      _errorMessage = e.toString();
      debugPrint('Error loading mileage data: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void _refreshRecommendations(DateTime? baselineDate) {
    final current = currentOdometerKm;
    if (current == null) {
      _recommendations = [];
      return;
    }

    final baseline = baselineDate ??
        (_readings.isNotEmpty
            ? _readings.last.readingDate
            : DateTime.now());

    _recommendations =
        MaintenanceRecommendationService.buildRecommendations(
      currentOdometerKm: current,
      maintenanceLogs: _maintenanceLogs,
      baselineDate: baseline,
    );
  }

  Future<bool> addMileageReading({
    required String carId,
    required double odometerKm,
    required DateTime readingDate,
    String? notes,
  }) async {
    final userId = SupabaseConfig.client.auth.currentUser?.id;
    if (userId == null) return false;

    if (_readings.isNotEmpty && odometerKm < _readings.first.odometerKm) {
      _errorMessage =
          'El odómetro no puede ser menor a la última lectura (${_readings.first.odometerKm.toStringAsFixed(0)} km)';
      notifyListeners();
      return false;
    }

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final reading = MileageReading(
        userId: userId,
        carId: carId,
        odometerKm: odometerKm,
        readingDate: readingDate,
        notes: notes,
      );
      await _dbHelper.insertMileageReading(reading);
      await loadForCar(carId);
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> markMaintenanceDone({
    required String carId,
    required String serviceType,
    required double odometerKm,
    String? notes,
  }) async {
    final userId = SupabaseConfig.client.auth.currentUser?.id;
    if (userId == null) return false;

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final log = MaintenanceLog(
        userId: userId,
        carId: carId,
        serviceType: serviceType,
        odometerKm: odometerKm,
        serviceDate: DateTime.now(),
        notes: notes,
      );
      await _dbHelper.insertMaintenanceLog(log);
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
