import 'package:purchases_flutter/purchases_flutter.dart';
import '../services/subscription_service.dart';

/// Identificador de la tarjeta del plan gratuito (no es un paquete de la tienda).
const String freePlanId = 'free';

/// Qué hace el botón principal de la pantalla de planes.
enum PlanAction {
  /// Seguir con el plan gratuito.
  continueFree,

  /// Comprar el plan elegido (el usuario aún no es premium).
  subscribe,

  /// Cambiar de mensual a anual (o al revés) siendo ya premium.
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

/// Plan que el usuario tiene hoy: [freePlanId], el identificador del paquete
/// que corresponde a su suscripción, o null si es premium pero ese paquete no
/// está en la oferta actual (no hay nada que marcar).
String? currentPlanId(SubscriptionTier tier, List<Package> packages) {
  switch (tier) {
    case SubscriptionTier.free:
      return freePlanId;
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

/// Plan marcado en pantalla: lo que el usuario tocó ([chosen]) y, mientras no
/// haya tocado nada, **el plan que ya tiene** (no siempre el gratuito).
String? selectedPlanId({
  required SubscriptionTier tier,
  required List<Package> packages,
  String? chosen,
}) => chosen ?? currentPlanId(tier, packages);

/// Acción del botón principal según el plan actual y el elegido.
PlanAction actionFor({
  required SubscriptionTier tier,
  required List<Package> packages,
  required String? selectedId,
}) {
  final isSubscribed = tier != SubscriptionTier.free;
  if (!isSubscribed) {
    return selectedId == null || selectedId == freePlanId
        ? PlanAction.continueFree
        : PlanAction.subscribe;
  }
  // Ya es premium: volver al gratuito o quedarse es administrar en la tienda.
  if (selectedId == null ||
      selectedId == freePlanId ||
      selectedId == currentPlanId(tier, packages)) {
    return PlanAction.manage;
  }
  return PlanAction.switchPlan;
}
