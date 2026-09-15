import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/geo_utils.dart';

/// Estado de un viaje GPS activo (persistido para sobrevivir reinicios de app).
class ActiveTripState {
  final String carId;
  final DateTime startedAt;
  final double distanceMeters;
  final double? lastLat;
  final double? lastLng;

  const ActiveTripState({
    required this.carId,
    required this.startedAt,
    required this.distanceMeters,
    this.lastLat,
    this.lastLng,
  });

  double get distanceKm => metersToKm(distanceMeters);

  Duration get elapsed => DateTime.now().difference(startedAt);
}

class TripTrackingService {
  TripTrackingService._();
  static final TripTrackingService instance = TripTrackingService._();

  static const _keyCarId = 'active_trip_car_id';
  static const _keyStartedAt = 'active_trip_started_at';
  static const _keyDistanceM = 'active_trip_distance_m';
  static const _keyLastLat = 'active_trip_last_lat';
  static const _keyLastLng = 'active_trip_last_lng';

  /// Ignora saltos GPS menores a 8 m (ruido estacionario).
  static const double _minSegmentMeters = 8;

  /// Descarta segmentos > 200 m en < 5 s (teletransporte GPS).
  static const double _maxSegmentMeters = 200;

  StreamSubscription<Position>? _positionSub;
  ActiveTripState? _activeTrip;
  final _tripController = StreamController<ActiveTripState>.broadcast();

  Stream<ActiveTripState> get tripStream => _tripController.stream;
  ActiveTripState? get activeTrip => _activeTrip;
  bool get isTracking => _activeTrip != null;

  Future<bool> requestBackgroundPermissions() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      debugPrint('GPS desactivado en el dispositivo');
      return false;
    }

    if (Platform.isAndroid) {
      var status = await Permission.locationWhenInUse.request();
      if (!status.isGranted) return false;

      status = await Permission.locationAlways.request();
      if (!status.isGranted) {
        // Algunos dispositivos solo conceden "while in use" — permitir intentar
        final fallback = await Geolocator.checkPermission();
        return fallback == LocationPermission.whileInUse ||
            fallback == LocationPermission.always;
      }
      return true;
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      return false;
    }

    if (permission == LocationPermission.whileInUse) {
      permission = await Geolocator.requestPermission();
    }

    return permission == LocationPermission.always ||
        permission == LocationPermission.whileInUse;
  }

  Future<void> restoreActiveTrip() async {
    if (_activeTrip != null) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      final carId = prefs.getString(_keyCarId);
      final startedAtStr = prefs.getString(_keyStartedAt);
      if (carId == null || startedAtStr == null) return;

      _activeTrip = ActiveTripState(
        carId: carId,
        startedAt: DateTime.parse(startedAtStr),
        distanceMeters: prefs.getDouble(_keyDistanceM) ?? 0,
        lastLat: prefs.getDouble(_keyLastLat),
        lastLng: prefs.getDouble(_keyLastLng),
      );

      // iOS crashea si se activa GPS en background sin permiso "Siempre"
      final canTrack = await _canStartGpsStream();
      if (canTrack) {
        await _startGpsStream();
      } else {
        debugPrint(
          'Viaje restaurado sin GPS activo (faltan permisos de ubicación)',
        );
      }

      if (!_tripController.isClosed) {
        _tripController.add(_activeTrip!);
      }
    } catch (e, stack) {
      debugPrint('Error restaurando viaje activo: $e\n$stack');
    }
  }

  Future<bool> _canStartGpsStream() async {
    if (!await Geolocator.isLocationServiceEnabled()) return false;

    final permission = await Geolocator.checkPermission();
    return permission == LocationPermission.always ||
        permission == LocationPermission.whileInUse;
  }

  Future<bool> startTrip(String carId) async {
    if (_activeTrip != null) {
      debugPrint('Ya hay un viaje activo');
      return false;
    }

    final granted = await requestBackgroundPermissions();
    if (!granted) return false;

    _activeTrip = ActiveTripState(
      carId: carId,
      startedAt: DateTime.now(),
      distanceMeters: 0,
    );

    await _persistState();
    await _startGpsStream();
    _tripController.add(_activeTrip!);
    return true;
  }

  Future<ActiveTripState?> stopTrip() async {
    final trip = _activeTrip;
    if (trip == null) return null;

    await _positionSub?.cancel();
    _positionSub = null;
    _activeTrip = null;
    await _clearPersistedState();
    return trip;
  }

  Future<void> _startGpsStream() async {
    if (!await _canStartGpsStream()) {
      debugPrint('GPS no disponible: servicio desactivado o sin permisos');
      return;
    }

    await _positionSub?.cancel();

    final settings = await _buildLocationSettings();

    _positionSub = Geolocator.getPositionStream(locationSettings: settings)
        .listen(_onPosition, onError: (e) {
      debugPrint('Error GPS: $e');
    });
  }

  Future<LocationSettings> _buildLocationSettings() async {
    if (Platform.isAndroid) {
      return AndroidSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 5,
        foregroundNotificationConfig: const ForegroundNotificationConfig(
          notificationTitle: 'MyCar — Viaje en curso',
          notificationText: 'Registrando kilómetros recorridos',
          notificationChannelName: 'Seguimiento de viajes',
          enableWakeLock: true,
        ),
      );
    }

    final permission = await Geolocator.checkPermission();
    final hasAlways = permission == LocationPermission.always;

    // allowBackgroundLocationUpdates=true SIN permiso Always provoca crash en iOS
    return AppleSettings(
      accuracy: LocationAccuracy.high,
      activityType: ActivityType.automotiveNavigation,
      distanceFilter: 5,
      pauseLocationUpdatesAutomatically: false,
      showBackgroundLocationIndicator: hasAlways,
      allowBackgroundLocationUpdates: hasAlways,
    );
  }

  void _onPosition(Position position) {
    final trip = _activeTrip;
    if (trip == null) return;

    final lat = position.latitude;
    final lng = position.longitude;

    double newDistance = trip.distanceMeters;

    if (trip.lastLat != null && trip.lastLng != null) {
      final segment = haversineDistanceMeters(
        trip.lastLat!,
        trip.lastLng!,
        lat,
        lng,
      );

      if (segment >= _minSegmentMeters && segment <= _maxSegmentMeters) {
        newDistance += segment;
      }
    }

    _activeTrip = ActiveTripState(
      carId: trip.carId,
      startedAt: trip.startedAt,
      distanceMeters: newDistance,
      lastLat: lat,
      lastLng: lng,
    );

    _persistState();
    _tripController.add(_activeTrip!);
  }

  Future<void> _persistState() async {
    final trip = _activeTrip;
    if (trip == null) return;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyCarId, trip.carId);
    await prefs.setString(_keyStartedAt, trip.startedAt.toIso8601String());
    await prefs.setDouble(_keyDistanceM, trip.distanceMeters);
    if (trip.lastLat != null) await prefs.setDouble(_keyLastLat, trip.lastLat!);
    if (trip.lastLng != null) await prefs.setDouble(_keyLastLng, trip.lastLng!);
  }

  Future<void> _clearPersistedState() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyCarId);
    await prefs.remove(_keyStartedAt);
    await prefs.remove(_keyDistanceM);
    await prefs.remove(_keyLastLat);
    await prefs.remove(_keyLastLng);
  }

  void dispose() {
    _positionSub?.cancel();
    _tripController.close();
  }
}
