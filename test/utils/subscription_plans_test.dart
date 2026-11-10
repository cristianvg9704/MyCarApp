import 'package:flutter_test/flutter_test.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:new_my_car_app/services/subscription_service.dart';
import 'package:new_my_car_app/utils/subscription_plans.dart';

Package pkg(String id, String productId) => Package(
  id,
  id.contains('annual') ? PackageType.annual : PackageType.monthly,
  StoreProduct(productId, 'desc', 'title', 5, r'$5.00', 'USD'),
  const PresentedOfferingContext('default', null, null),
);

void main() {
  final monthly = pkg(r'$rc_monthly', 'rc_monthly');
  final yearly = pkg(r'$rc_annual', 'rc_annual');
  final both = [monthly, yearly];

  group('detección de paquetes', () {
    test('mensual por identificador o por producto', () {
      expect(isMonthlyPackage(monthly), isTrue);
      expect(isMonthlyPackage(pkg('custom', 'rc_monthly')), isTrue);
      expect(isMonthlyPackage(pkg('mensual', 'x')), isTrue);
      expect(isMonthlyPackage(yearly), isFalse);
    });

    test('anual por identificador o por producto', () {
      expect(isYearlyPackage(yearly), isTrue);
      expect(isYearlyPackage(pkg('custom', 'rc_annual')), isTrue);
      expect(isYearlyPackage(pkg('x', 'yearly_subscription')), isTrue);
      expect(isYearlyPackage(pkg('anual', 'x')), isTrue);
      expect(isYearlyPackage(monthly), isFalse);
    });
  });

  group('currentPlanId', () {
    test('gratuito', () {
      expect(currentPlanId(SubscriptionTier.free, both), freePlanId);
      expect(currentPlanId(SubscriptionTier.free, const []), freePlanId);
    });

    test('mensual y anual apuntan a su paquete', () {
      expect(currentPlanId(SubscriptionTier.monthly, both), monthly.identifier);
      expect(currentPlanId(SubscriptionTier.yearly, both), yearly.identifier);
    });

    test('premium sin ese paquete en la oferta no marca nada', () {
      expect(currentPlanId(SubscriptionTier.yearly, [monthly]), isNull);
      expect(currentPlanId(SubscriptionTier.monthly, const []), isNull);
    });
  });

  group('selectedPlanId', () {
    test('sin elegir nada marca el plan que ya tienes, no el gratuito', () {
      expect(
        selectedPlanId(tier: SubscriptionTier.monthly, packages: both),
        monthly.identifier,
      );
      expect(
        selectedPlanId(tier: SubscriptionTier.yearly, packages: both),
        yearly.identifier,
      );
    });

    test('un usuario gratuito empieza en el plan gratuito', () {
      expect(
        selectedPlanId(tier: SubscriptionTier.free, packages: both),
        freePlanId,
      );
    });

    test('lo que el usuario toca manda sobre el plan actual', () {
      expect(
        selectedPlanId(
          tier: SubscriptionTier.monthly,
          packages: both,
          chosen: yearly.identifier,
        ),
        yearly.identifier,
      );
      expect(
        selectedPlanId(
          tier: SubscriptionTier.monthly,
          packages: both,
          chosen: freePlanId,
        ),
        freePlanId,
      );
    });
  });

  group('actionFor', () {
    PlanAction action(SubscriptionTier tier, String? selected) =>
        actionFor(tier: tier, packages: both, selectedId: selected);

    test('usuario gratuito', () {
      expect(
        action(SubscriptionTier.free, freePlanId),
        PlanAction.continueFree,
      );
      expect(action(SubscriptionTier.free, null), PlanAction.continueFree);
      expect(
        action(SubscriptionTier.free, monthly.identifier),
        PlanAction.subscribe,
      );
      expect(
        action(SubscriptionTier.free, yearly.identifier),
        PlanAction.subscribe,
      );
    });

    test('premium con su plan marcado administra la suscripción', () {
      expect(
        action(SubscriptionTier.monthly, monthly.identifier),
        PlanAction.manage,
      );
      expect(
        action(SubscriptionTier.yearly, yearly.identifier),
        PlanAction.manage,
      );
    });

    test('premium que elige el otro plan lo cambia', () {
      expect(
        action(SubscriptionTier.monthly, yearly.identifier),
        PlanAction.switchPlan,
      );
      expect(
        action(SubscriptionTier.yearly, monthly.identifier),
        PlanAction.switchPlan,
      );
    });

    test('premium que elige el gratuito va a administrar (cancelar)', () {
      expect(action(SubscriptionTier.monthly, freePlanId), PlanAction.manage);
      expect(action(SubscriptionTier.yearly, freePlanId), PlanAction.manage);
    });

    test('premium sin nada marcado administra', () {
      expect(action(SubscriptionTier.monthly, null), PlanAction.manage);
    });
  });
}
