import 'package:flutter_test/flutter_test.dart';
import 'package:new_my_car_app/services/subscription_service.dart';

void main() {
  group('subscriptionTierFromName (plan guardado en el teléfono)', () {
    test('reconoce los dos planes', () {
      expect(subscriptionTierFromName('monthly'), SubscriptionTier.monthly);
      expect(subscriptionTierFromName('yearly'), SubscriptionTier.yearly);
    });

    test('sin valor, "none" o un valor antiguo/desconocido: sin plan', () {
      expect(subscriptionTierFromName(null), SubscriptionTier.none);
      expect(subscriptionTierFromName('none'), SubscriptionTier.none);
      expect(subscriptionTierFromName('free'), SubscriptionTier.none);
      expect(subscriptionTierFromName('lifetime'), SubscriptionTier.none);
      expect(subscriptionTierFromName(''), SubscriptionTier.none);
    });

    test('es coherente con lo que se guarda al cambiar de plan', () {
      for (final tier in SubscriptionTier.values) {
        expect(subscriptionTierFromName(tier.name), tier);
      }
    });
  });
}
