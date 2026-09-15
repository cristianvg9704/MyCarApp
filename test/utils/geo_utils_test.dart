import 'package:flutter_test/flutter_test.dart';
import 'package:new_my_car_app/utils/geo_utils.dart';

void main() {
  test('haversineDistanceMeters returns ~0 for same point', () {
    expect(
      haversineDistanceMeters(4.6097, -74.0817, 4.6097, -74.0817),
      lessThan(1),
    );
  });

  test('haversineDistanceMeters calculates known distance', () {
    // Bogotá centro ~5 km apart prox
    final meters = haversineDistanceMeters(
      4.6097,
      -74.0817,
      4.6546,
      -74.0817,
    );
    expect(meters, greaterThan(4000));
    expect(meters, lessThan(6000));
  });

  test('metersToKm rounds to one decimal', () {
    expect(metersToKm(1234), 1.2);
    expect(metersToKm(1250), 1.3);
  });
}
