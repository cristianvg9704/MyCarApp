import 'package:flutter_test/flutter_test.dart';
import 'package:new_my_car_app/utils/trip_format.dart';

void main() {
  test('formatea mm:ss por debajo de una hora', () {
    expect(formatTripDuration(Duration.zero), '00:00');
    expect(formatTripDuration(const Duration(minutes: 5, seconds: 7)), '05:07');
    expect(
      formatTripDuration(const Duration(minutes: 59, seconds: 59)),
      '59:59',
    );
  });

  test('formatea h:mm:ss desde una hora', () {
    expect(formatTripDuration(const Duration(hours: 1)), '1:00:00');
    expect(
      formatTripDuration(const Duration(hours: 2, minutes: 3, seconds: 4)),
      '2:03:04',
    );
  });
}
