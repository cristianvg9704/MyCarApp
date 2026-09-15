import 'dart:async';
import 'package:flutter/material.dart';
import '../models/trip_log.dart';
import '../services/database_helper.dart';
import '../services/trip_tracking_service.dart';
import '../config/supabase_config.dart';
import 'mileage_provider.dart';

class TripProvider extends ChangeNotifier {
  final TripTrackingService _tracking = TripTrackingService.instance;
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  StreamSubscription<ActiveTripState>? _tripSub;
  List<TripLog> _trips = [];
  ActiveTripState? _liveTrip;
  bool _isLoading = false;
  String? _errorMessage;
  String? _loadedCarId;

  List<TripLog> get trips => _trips;
  ActiveTripState? get liveTrip => _liveTrip;
  bool get isTracking => _liveTrip != null;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  double get liveDistanceKm => _liveTrip?.distanceKm ?? 0;

  Duration get liveDuration => _liveTrip?.elapsed ?? Duration.zero;

  Future<void> initialize() async {
    try {
      _tripSub ??= _tracking.tripStream.listen((state) {
        _liveTrip = state;
        notifyListeners();
      });
      await _tracking.restoreActiveTrip();
      _liveTrip = _tracking.activeTrip;
    } catch (e, stack) {
      debugPrint('Error inicializando TripProvider: $e\n$stack');
    } finally {
      notifyListeners();
    }
  }

  Future<void> loadTripsForCar(String carId) async {
    _loadedCarId = carId;
    try {
      _trips = await _dbHelper.getTripLogsByCar(carId);
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading trips: $e');
    }
  }

  Future<bool> startTrip(String carId) async {
    _errorMessage = null;

    if (_tracking.isTracking && _tracking.activeTrip?.carId != carId) {
      _errorMessage = 'Ya hay un viaje activo en otro vehículo';
      notifyListeners();
      return false;
    }

    final started = await _tracking.startTrip(carId);
    if (!started) {
      _errorMessage =
          'No se pudo iniciar el GPS. Activa la ubicación y concede permiso "Siempre".';
      notifyListeners();
      return false;
    }

    _liveTrip = _tracking.activeTrip;
    notifyListeners();
    return true;
  }

  Future<TripLog?> stopTrip({
    required MileageProvider mileageProvider,
    required bool updateOdometer,
  }) async {
    final ended = await _tracking.stopTrip();
    if (ended == null) return null;

    _liveTrip = null;
    _isLoading = true;
    notifyListeners();

    try {
      final userId = SupabaseConfig.client.auth.currentUser?.id;
      if (userId == null) return null;

      final endedAt = DateTime.now();
      final distanceKm = ended.distanceKm;
      final startOdometer = mileageProvider.currentOdometerKm;
      double? endOdometer;

      if (updateOdometer && distanceKm > 0) {
        endOdometer = (startOdometer ?? 0) + distanceKm;
        await mileageProvider.addMileageReading(
          carId: ended.carId,
          odometerKm: endOdometer,
          readingDate: endedAt,
          notes: 'Actualizado automáticamente desde viaje GPS (+${distanceKm.toStringAsFixed(1)} km)',
        );
      }

      final tripLog = TripLog(
        userId: userId,
        carId: ended.carId,
        distanceKm: distanceKm,
        startedAt: ended.startedAt,
        endedAt: endedAt,
        durationSeconds: endedAt.difference(ended.startedAt).inSeconds,
        startOdometerKm: startOdometer,
        endOdometerKm: endOdometer,
      );

      await _dbHelper.insertTripLog(tripLog);

      if (_loadedCarId == ended.carId) {
        await loadTripsForCar(ended.carId);
      }

      _isLoading = false;
      notifyListeners();
      return tripLog;
    } catch (e) {
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
      return null;
    }
  }

  @override
  void dispose() {
    _tripSub?.cancel();
    super.dispose();
  }
}
