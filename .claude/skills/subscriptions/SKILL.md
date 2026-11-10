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

## Modelo de planes (no hay plan gratuito)
La app **se usa con una suscripción**: mensual o anual. No existe plan gratuito; `SubscriptionTier.none` significa "sin
suscripción activa" (nunca compró, venció o canceló).

| | Mensual (`rc_monthly`) | Anual (`rc_annual`) |
|---|---|---|
| Vehículos | hasta **15** (`monthlyVehicleLimit`) | **ilimitados** |
| Alertas | sí | sí, **las mismas** (ninguno es "más avanzado") |
| Soporte | sí | **prioritario** |

Reglas en `lib/utils/subscription_plans.dart` (puras y probadas): `planFeatures`, `vehicleLimitFor`, `canAddVehicle`,
`currentPlanId`, `selectedPlanId`, `actionFor`, `subscriptionGateRedirect` (y `appRedirect`). Para cambiar un tope o un beneficio, se cambia ahí y
en `subscriptionScreen`/legal (ver abajo).

### Acceso a la app (onboarding, login y paywall)
Una sola regla pura, `appRedirect` (`lib/utils/app_redirect.dart`, con tests), que usa el `redirect` del router (`lib/main.dart`):
- **Sin sesión:** la primera vez, onboarding (se recuerda con `onboarding_completed`, también al "Saltar"); después, login.
- **Con sesión y plan activo (usuario normal):** entra directo al inicio, **sin onboarding, login ni planes**. Los planes solo
  se abren desde Ajustes.
- **Con sesión y sin plan:** solo `/subscription` (`subscriptionGateRedirect`). Tras iniciar sesión `goAfterSignIn` va a `/home`
  y el router lo desvía a los planes si hace falta.
- Ya no existe el modo dev/prod (`AppConfig`): el onboarding sale una sola vez en cualquier build. Para volver a verlo durante
  el desarrollo, desinstala la app o borra sus datos.
- La pantalla sin plan **no se puede cerrar** (sin X, `PopScope` bloquea "atrás"). Solo ofrece: elegir plan, **Restaurar
  compras**, **Cerrar sesión** y **Eliminar mi cuenta** (Apple 5.1.1(v); `lib/utils/account_actions.dart`, compartido con Ajustes).
- El plan se carga en `main()` (`SubscriptionService.initialize`) antes de `runApp`, así que el primer `redirect` ya lo conoce.
  El router no escucha cambios: si el plan vence con la app abierta, se aplica en la siguiente navegación.
- Si RevenueCat no está configurado (clave vacía en `.env`) el tier queda en `none` y el paywall bloquea la app.

### El plan viaja con la cuenta (identidad en RevenueCat)
- Al iniciar sesión (correo, Apple o Google), `AuthProvider` llama `onSignedIn` → `SubscriptionService.identifyUser(userId)`
  (`Purchases.logIn` con el id de Supabase) y actualiza el plan **antes** de decidir a dónde ir. Así un usuario que ya pagó no cae
  en el paywall al reinstalar o cambiar de iPhone. Al abrir la app con sesión, `initialize` vuelve a identificarlo con el id guardado.
- Al cerrar sesión, `onSignedOut` → `logOutUser`: desvincula las compras y borra el plan guardado, para que otra persona que use
  el teléfono no herede el plan.
- Si RevenueCat falla (sin internet, servicio caído) se usa el **último plan conocido** guardado en el teléfono
  (`subscription_tier`, `subscriptionTierFromName`), para no bloquear a quien ya pagó; la siguiente consulta exitosa lo corrige.

### Límite de vehículos
- `CarProvider(vehicleLimit: ...)` (en `main.dart` lee el plan actual): `canAddCar`, `vehicleLimit` y `addCar` lanza
  `VehicleLimitReachedException` al llegar al tope, así que ninguna pantalla se lo salta.
- `VehicleModalHelper.showAddVehicleModal` avisa **antes** de abrir el formulario (`VehicleLimitDialog`: "Ver planes" /
  "Ahora no"); `AddVehicleScreen` muestra el mismo aviso si el guardado lo rechaza.
- **Es solo del cliente**: la base de datos no impone el tope (un cliente modificado podría saltarlo). Un trigger/RLS en
  Supabase que cuente `cars` por usuario lo haría cumplir en el servidor (pendiente).

## "Administrar suscripción" (cancelar o cambiar de plan)
Las tiendas no permiten cancelar desde dentro de la app: solo se abre su pantalla de suscripciones
(`SubscriptionProvider.openManageSubscription`, `lib/utils/subscription_management.dart`).
- **iOS:** se intenta primero `itms-apps://apps.apple.com/account/subscriptions`, que abre **directamente la app App Store**
  (en vez de Safari); si no se puede (el **simulador no tiene App Store**) se cae a `https://apps.apple.com/account/subscriptions`.
  Si RevenueCat entrega `managementURL`, se usa esa.
- **Android:** `https://play.google.com/store/account/subscriptions`.
- Si nada abre, la pantalla muestra un aviso para hacerlo desde los ajustes de la cuenta.
- Alternativa más nativa (pendiente): la hoja de StoreKit `AppStore.showManageSubscriptions(in:)` (iOS 15+) dentro de la app,
  que requiere un `MethodChannel` en Swift (`purchases_flutter` 10.x no la expone).

## Pantalla de planes (`SubscriptionScreen`)
- **Tarjetas:** una por paquete de la oferta (Mensual / Anual) con `planFeatures`. El **precio sale de la tienda**
  (`storeProduct.priceString`), nunca escrito a mano; debajo, el texto de renovación automática.
- **Plan marcado:** lo que el usuario tocó; si no ha tocado nada, **su plan actual**; sin plan, el **anual** (o el primero de la
  oferta). Si el plan llega después de abrir la pantalla, la selección se actualiza sola.
- **"PLAN ACTUAL":** insignia en la tarjeta del plan que tiene el usuario.
- **Botón principal:**
  | Situación | Botón |
  |---|---|
  | Sin plan | "Suscribirse Ahora" |
  | Suscriptor, su plan marcado | "Administrar suscripción" (abre la tienda; `openManageSubscription`) |
  | Suscriptor, el otro plan marcado | "Cambiar a plan Anual / Mensual" (compra; ambos van en el mismo grupo de suscripciones) |
- Un suscriptor cuyo paquete no está en la oferta actual no tiene nada marcado (no se adivina).
- Pendiente (Apple): enlaces a Política de Privacidad y Términos en esta pantalla.
- Tests: `test/utils/subscription_plans_test.dart`, `test/utils/app_redirect_test.dart`, `test/services/subscription_tier_test.dart`,
  `test/providers/auth_provider_social_test.dart` (grupo "asociar las compras"), `test/widgets/onboarding_screen_test.dart`,
  `test/widgets/subscription_screen_test.dart`,
  `test/providers/car_provider_test.dart` (grupo "límite de vehículos"), `test/widgets/vehicle_limit_test.dart`.
