import 'package:purchases_flutter/purchases_flutter.dart';
import '../services/subscription_service.dart';

/// Reglas de los planes de MyCar. **No hay plan gratuito**: la app se usa con
/// una suscripción mensual o anual.
///
/// | | Mensual | Anual |
/// |---|---|---|
/// | Vehículos | hasta [monthlyVehicleLimit] | ilimitados |
/// | Alertas | sí | sí (las mismas) |
/// | Soporte | sí | **prioritario** |

/// Máximo de vehículos del plan mensual.
const int monthlyVehicleLimit = 15;

/// Qué hace el botón principal de la pantalla de planes.
enum PlanAction {
  /// Comprar el plan elegido (el usuario aún no tiene plan).
  subscribe,

  /// Cambiar de mensual a anual (o al revés) siendo ya suscriptor.
  switchPlan,

  /// Abrir la administración de la suscripción de la tienda (cancelar, ver
  /// renovación). Apple/Google no permiten cancelar desde dentro de la app.
  manage,
}

String _text(Package p) =>
    '${p.identifier} ${p.storeProduct.identifier}'.toLowerCase();

bool isMonthlyPackage(Package package) {
  final text = _text(package);
  return text.contains('monthly') || text.contains('mensual');
}

bool isYearlyPackage(Package package) {
  final text = _text(package);
  return text.contains('yearly') ||
      text.contains('annual') ||
      text.contains('anual');
}

/// Lo que incluye cada plan, para mostrar en su tarjeta. Las alertas son las
/// mismas en ambos: el anual no es "más avanzado", solo no tiene tope de
/// vehículos y tiene soporte prioritario.
List<String> planFeatures(Package package) {
  if (isYearlyPackage(package)) {
    return const [
      'Vehículos ilimitados',
      'Alertas y recordatorios',
      'Soporte prioritario',
    ];
  }
  return const [
    'Hasta $monthlyVehicleLimit vehículos',
    'Alertas y recordatorios',
    'Soporte',
  ];
}

// --- Límite de vehículos ----------------------------------------------------

/// Cuántos vehículos permite el plan; `null` = ilimitados. Sin suscripción no
/// se puede agregar ninguno.
int? vehicleLimitFor(SubscriptionTier tier) {
  switch (tier) {
    case SubscriptionTier.none:
      return 0;
    case SubscriptionTier.monthly:
      return monthlyVehicleLimit;
    case SubscriptionTier.yearly:
      return null;
  }
}

bool canAddVehicle(SubscriptionTier tier, int currentCount) {
  final limit = vehicleLimitFor(tier);
  return limit == null || currentCount < limit;
}

// --- Plan marcado en la pantalla de planes ------------------------------------

/// Plan que el usuario tiene hoy: el identificador del paquete que corresponde
/// a su suscripción, o null si no tiene plan o su paquete no está en la oferta
/// actual (no hay nada que marcar como "actual").
String? currentPlanId(SubscriptionTier tier, List<Package> packages) {
  switch (tier) {
    case SubscriptionTier.none:
      return null;
    case SubscriptionTier.monthly:
      return _firstWhere(packages, isMonthlyPackage)?.identifier;
    case SubscriptionTier.yearly:
      return _firstWhere(packages, isYearlyPackage)?.identifier;
  }
}

Package? _firstWhere(List<Package> packages, bool Function(Package) test) {
  for (final package in packages) {
    if (test(package)) return package;
  }
  return null;
}

/// Plan marcado en pantalla: lo que el usuario tocó ([chosen]); mientras no
/// toque nada, **su plan actual**, y si aún no tiene plan, el anual (el de más
/// valor) o, si no existe, el primero de la oferta.
String? selectedPlanId({
  required SubscriptionTier tier,
  required List<Package> packages,
  String? chosen,
}) {
  if (chosen != null) return chosen;
  final current = currentPlanId(tier, packages);
  if (current != null) return current;
  if (tier != SubscriptionTier.none) return null;
  return (_firstWhere(packages, isYearlyPackage) ??
          (packages.isEmpty ? null : packages.first))
      ?.identifier;
}

/// Acción del botón principal según el plan actual y el elegido.
PlanAction actionFor({
  required SubscriptionTier tier,
  required List<Package> packages,
  required String? selectedId,
}) {
  if (tier == SubscriptionTier.none) return PlanAction.subscribe;
  // Ya es suscriptor: quedarse en su plan es administrarlo en la tienda.
  if (selectedId == null || selectedId == currentPlanId(tier, packages)) {
    return PlanAction.manage;
  }
  return PlanAction.switchPlan;
}

// --- Acceso a la app -----------------------------------------------------------

/// Rutas que se pueden ver sin suscripción (para elegir un plan).
const String subscriptionRoute = '/subscription';

/// A dónde mandar a un usuario que inició sesión pero **no tiene plan**: a la
/// pantalla de planes. Null si no hay que redirigir (no inició sesión, ya tiene
/// plan, o ya está en la pantalla de planes).
String? subscriptionGateRedirect({
  required bool isAuthenticated,
  required bool hasPlan,
  required String path,
}) {
  if (!isAuthenticated || hasPlan) return null;
  if (path == subscriptionRoute) return null;
  return subscriptionRoute;
}
