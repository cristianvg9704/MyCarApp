import 'dart:math';

/// Distancia en metros entre dos coordenadas (fórmula de Haversine).
double haversineDistanceMeters(
  double lat1,
  double lon1,
  double lat2,
  double lon2,
) {
  const earthRadiusM = 6371000.0;
  final dLat = _toRadians(lat2 - lat1);
  final dLon = _toRadians(lon2 - lon1);
  final a = sin(dLat / 2) * sin(dLat / 2) +
      cos(_toRadians(lat1)) *
          cos(_toRadians(lat2)) *
          sin(dLon / 2) *
          sin(dLon / 2);
  final c = 2 * atan2(sqrt(a), sqrt(1 - a));
  return earthRadiusM * c;
}

double _toRadians(double degrees) => degrees * pi / 180;

/// Convierte metros a kilómetros con un decimal.
double metersToKm(double meters) => (meters / 1000 * 10).round() / 10;
