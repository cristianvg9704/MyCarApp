---
name: subscriptions
description: Suscripción premium (RevenueCat) y administración/cancelación del plan. Úsalo al tocar SubscriptionService, SubscriptionProvider, la pantalla de suscripción, la tarjeta "Administrar suscripción" de Ajustes o la configuración de productos en RevenueCat/App Store/Google Play.
---

# Suscripciones (RevenueCat)

## Qué hace
Vende el plan **MyCarApp Pro** (mensual / anual) con RevenueCat y permite al usuario administrarlo.

## Archivos y capas
- `lib/services/subscription_service.dart`: singleton sobre `purchases_flutter` (configura, ofertas, compra,
  restaurar, `getManagementUrl`).
- `lib/providers/subscription_provider.dart`: estado para la UI. `SubscriptionProvider({fetchManagementUrl,
  launchUri, platform})` es inyectable para probar sin RevenueCat ni navegador.
- `lib/utils/subscription_management.dart`: `subscriptionManagementUrl` (función pura).
- `lib/screens/subscription_screen.dart`: planes y compra. `lib/screens/settings_screen.dart`: estado del plan,
  restaurar compras y **Administrar suscripción**.

## Reglas de negocio
- Constantes que deben coincidir con las tiendas/RevenueCat: productos `rc_monthly` y `rc_annual`,
  entitlement `MyCarApp Pro`, offering marcado como *Current*.
- **Cancelar no se puede desde la app**: Apple y Google solo permiten hacerlo en su pantalla de suscripciones.
  La tarjeta "Administrar suscripción" (solo visible con plan activo) abre esa pantalla: usa la
  `managementURL` de RevenueCat y, si no hay, `apps.apple.com/account/subscriptions` (iOS) o
  `play.google.com/store/account/subscriptions` (Android). En escritorio/web no hay tienda y no hace nada.
- Si no se puede abrir, se muestra un aviso indicando que se haga desde los ajustes de la cuenta en la tienda.

## Configuración fuera del código
- iOS: Paid Apps Agreement firmado, suscripciones `rc_monthly`/`rc_annual` en App Store Connect, claves
  .p8 en RevenueCat, entitlement y offering `default` con paquetes Monthly/Annual.
- Android: necesita su propia SDK key `goog_…` (hoy el código reutiliza la de iOS) y productos en Google Play.
- Con `flutter run` en un iPhone se usa el sandbox real de Apple (el `.storekit` solo funciona desde Xcode).

## Cómo se prueba
- `flutter test test/utils/subscription_management_test.dart test/providers/subscription_provider_test.dart`.
- Manual (iPhone, con suscripción sandbox activa): Ajustes → Administrar suscripción → debe abrir la pantalla
  de suscripciones de Apple, donde se cancela.

## Pantalla de planes (`SubscriptionScreen`)
La lógica de qué plan se marca y qué hace el botón es pura y vive en `lib/utils/subscription_plans.dart`
(`currentPlanId`, `selectedPlanId`, `actionFor`, `isMonthlyPackage`, `isYearlyPackage`).
- **Plan marcado:** lo que el usuario tocó; mientras no toque nada, **el plan que ya tiene** (`SubscriptionProvider.currentTier`):
  gratuito, mensual o anual. Nunca se marca el gratuito por defecto a alguien que ya compró (era el bug). Si llega el plan
  después de abrir la pantalla, la selección se actualiza sola.
- **"PLAN ACTUAL":** insignia en la tarjeta del plan que tiene el usuario (también en el gratuito si no ha comprado).
- **Botón principal según el caso:**
  | Situación | Botón |
  |---|---|
  | Gratuito, plan gratuito marcado | "Continuar con Plan Gratuito" |
  | Gratuito, plan de pago marcado | "Suscribirse Ahora" |
  | Premium, su plan marcado | "Administrar suscripción" (abre la tienda; `openManageSubscription`) |
  | Premium, el otro plan marcado | "Cambiar a plan Anual / Mensual" (compra; ambos van en el mismo grupo de suscripciones) |
  | Premium, plan gratuito marcado | "Administrar suscripción" + aviso: para volver al gratuito se cancela en la tienda |
- Un premium cuyo paquete no está en la oferta actual no tiene nada marcado (no se adivina).
- Tests: `test/utils/subscription_plans_test.dart` y `test/widgets/subscription_screen_test.dart` (proveedor falso).
