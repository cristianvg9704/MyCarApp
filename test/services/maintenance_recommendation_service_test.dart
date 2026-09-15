import 'package:flutter_test/flutter_test.dart';
import 'package:new_my_car_app/models/maintenance_log.dart';
import 'package:new_my_car_app/models/maintenance_recommendation.dart';
import 'package:new_my_car_app/models/mileage_reading.dart';
import 'package:new_my_car_app/services/maintenance_recommendation_service.dart';

void main() {
  group('MaintenanceRecommendationService', () {
    test('calculateTrackedKm sums positive deltas between readings', () {
      final readings = [
        MileageReading(
          userId: 'u1',
          carId: 'c1',
          odometerKm: 10000,
          readingDate: DateTime(2025, 1, 1),
        ),
        MileageReading(
          userId: 'u1',
          carId: 'c1',
          odometerKm: 10500,
          readingDate: DateTime(2025, 2, 1),
        ),
        MileageReading(
          userId: 'u1',
          carId: 'c1',
          odometerKm: 11200,
          readingDate: DateTime(2025, 3, 1),
        ),
      ];

      expect(
        MaintenanceRecommendationService.calculateTrackedKm(readings),
        1200,
      );
    });

    test('buildRecommendations marks oil change overdue after 5000 km', () {
      final recommendations =
          MaintenanceRecommendationService.buildRecommendations(
        currentOdometerKm: 6000,
        maintenanceLogs: const [],
        baselineDate: DateTime(2024, 1, 1),
      );

      final oil = recommendations.firstWhere(
        (r) => r.serviceType == 'oil_change',
      );

      expect(oil.status, MaintenanceStatus.overdue);
      expect(oil.kmSinceService, 6000);
    });

    test('buildRecommendations resets after maintenance log', () {
      final now = DateTime.now();
      final recommendations =
          MaintenanceRecommendationService.buildRecommendations(
        currentOdometerKm: 7000,
        maintenanceLogs: [
          MaintenanceLog(
            userId: 'u1',
            carId: 'c1',
            serviceType: 'oil_change',
            odometerKm: 5000,
            serviceDate: DateTime(now.year, now.month, 1),
          ),
        ],
        baselineDate: DateTime(now.year - 1, 1, 1),
      );

      final oil = recommendations.firstWhere(
        (r) => r.serviceType == 'oil_change',
      );

      expect(oil.status, MaintenanceStatus.ok);
      expect(oil.kmSinceService, 2000);
      expect(oil.kmRemaining, 3000);
    });
  });
}
