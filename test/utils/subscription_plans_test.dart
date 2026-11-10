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

  group('qué incluye cada plan', () {
    test('el mensual tiene tope de 15 vehículos y soporte normal', () {
      expect(planFeatures(monthly), [
        'Hasta 15 vehículos',
        'Alertas y recordatorios',
        'Soporte',
      ]);
    });

    test('el anual: vehículos ilimitados y soporte prioritario', () {
      expect(planFeatures(yearly), [
        'Vehículos ilimitados',
        'Alertas y recordatorios',
        'Soporte prioritario',
      ]);
    });

    test('las alertas son las mismas: ninguno es "más avanzado"', () {
      expect(
        planFeatures(monthly).where((f) => f.contains('Alertas')),
        planFeatures(yearly).where((f) => f.contains('Alertas')),
      );
      for (final p in both) {
        expect(
          planFeatures(p).any((f) => f.toLowerCase().contains('avanzad')),
          isFalse,
        );
      }
    });

    test('solo el anual tiene soporte prioritario', () {
      bool priority(Package p) =>
          planFeatures(p).contains('Soporte prioritario');
      expect(priority(yearly), isTrue);
      expect(priority(monthly), isFalse);
    });

    test('el plan gratuito no existe', () {
      expect(SubscriptionTier.values, [
        SubscriptionTier.none,
        SubscriptionTier.monthly,
        SubscriptionTier.yearly,
      ]);
    });
  });

  group('límite de vehículos', () {
    test('mensual: 15; anual: ilimitado; sin plan: ninguno', () {
      expect(monthlyVehicleLimit, 15);
      expect(vehicleLimitFor(SubscriptionTier.monthly), 15);
      expect(vehicleLimitFor(SubscriptionTier.yearly), isNull);
      expect(vehicleLimitFor(SubscriptionTier.none), 0);
    });

    test('canAddVehicle respeta el tope del plan mensual', () {
      expect(canAddVehicle(SubscriptionTier.monthly, 0), isTrue);
      expect(canAddVehicle(SubscriptionTier.monthly, 14), isTrue);
      expect(canAddVehicle(SubscriptionTier.monthly, 15), isFalse);
      expect(canAddVehicle(SubscriptionTier.monthly, 40), isFalse);
    });

    test('el plan anual no tiene tope', () {
      expect(canAddVehicle(SubscriptionTier.yearly, 15), isTrue);
      expect(canAddVehicle(SubscriptionTier.yearly, 5000), isTrue);
    });

    test('sin plan no se puede agregar ninguno', () {
      expect(canAddVehicle(SubscriptionTier.none, 0), isFalse);
    });
  });

  group('currentPlanId', () {
    test('sin plan no hay plan actual', () {
      expect(currentPlanId(SubscriptionTier.none, both), isNull);
    });

    test('mensual y anual apuntan a su paquete', () {
      expect(currentPlanId(SubscriptionTier.monthly, both), monthly.identifier);
      expect(currentPlanId(SubscriptionTier.yearly, both), yearly.identifier);
    });

    test('suscriptor sin ese paquete en la oferta no marca nada', () {
      expect(currentPlanId(SubscriptionTier.yearly, [monthly]), isNull);
      expect(currentPlanId(SubscriptionTier.monthly, const []), isNull);
    });
  });

  group('selectedPlanId', () {
    test('sin plan se marca el anual (el de más valor)', () {
      expect(
        selectedPlanId(tier: SubscriptionTier.none, packages: both),
        yearly.identifier,
      );
    });

    test('sin plan y sin anual en la oferta, el primero', () {
      expect(
        selectedPlanId(tier: SubscriptionTier.none, packages: [monthly]),
        monthly.identifier,
      );
      expect(
        selectedPlanId(tier: SubscriptionTier.none, packages: const []),
        isNull,
      );
    });

    test('un suscriptor ve marcado el plan que ya tiene', () {
      expect(
        selectedPlanId(tier: SubscriptionTier.monthly, packages: both),
        monthly.identifier,
      );
      expect(
        selectedPlanId(tier: SubscriptionTier.yearly, packages: both),
        yearly.identifier,
      );
    });

    test('lo que el usuario toca manda sobre todo lo demás', () {
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
          tier: SubscriptionTier.none,
          packages: both,
          chosen: monthly.identifier,
        ),
        monthly.identifier,
      );
    });

    test('suscriptor cuyo paquete no está en la oferta: nada marcado', () {
      expect(
        selectedPlanId(tier: SubscriptionTier.yearly, packages: [monthly]),
        isNull,
      );
    });
  });

  group('actionFor', () {
    PlanAction action(SubscriptionTier tier, String? selected) =>
        actionFor(tier: tier, packages: both, selectedId: selected);

    test('sin plan siempre es suscribirse', () {
      expect(
        action(SubscriptionTier.none, yearly.identifier),
        PlanAction.subscribe,
      );
      expect(
        action(SubscriptionTier.none, monthly.identifier),
        PlanAction.subscribe,
      );
      expect(action(SubscriptionTier.none, null), PlanAction.subscribe);
    });

    test('suscriptor con su plan marcado administra la suscripción', () {
      expect(
        action(SubscriptionTier.monthly, monthly.identifier),
        PlanAction.manage,
      );
      expect(
        action(SubscriptionTier.yearly, yearly.identifier),
        PlanAction.manage,
      );
      expect(action(SubscriptionTier.monthly, null), PlanAction.manage);
    });

    test('suscriptor que elige el otro plan lo cambia', () {
      expect(
        action(SubscriptionTier.monthly, yearly.identifier),
        PlanAction.switchPlan,
      );
      expect(
        action(SubscriptionTier.yearly, monthly.identifier),
        PlanAction.switchPlan,
      );
    });
  });

  group('subscriptionGateRedirect (la app exige un plan)', () {
    String? gate({
      bool isAuthenticated = true,
      bool hasPlan = false,
      String path = '/home',
    }) => subscriptionGateRedirect(
      isAuthenticated: isAuthenticated,
      hasPlan: hasPlan,
      path: path,
    );

    test('sin plan, todo lleva a la pantalla de planes', () {
      for (final path in ['/', '/home', '/profile', '/car-detail', '/alerts']) {
        expect(gate(path: path), '/subscription', reason: path);
      }
    });

    test('ya en la pantalla de planes no redirige (evita un bucle)', () {
      expect(gate(path: '/subscription'), isNull);
    });

    test('con plan activo no se redirige', () {
      expect(gate(hasPlan: true), isNull);
      expect(gate(hasPlan: true, path: '/subscription'), isNull);
    });

    test('sin sesión no aplica (el login va primero)', () {
      expect(gate(isAuthenticated: false), isNull);
      expect(gate(isAuthenticated: false, path: '/login'), isNull);
    });
  });
}
