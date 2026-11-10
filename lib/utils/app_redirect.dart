import 'subscription_plans.dart';

/// Rutas de autenticación (sin sesión).
const _authRoutes = {'/login', '/register', '/forgot-password'};

/// A dónde debe ir el usuario según su estado, o `null` si puede quedarse donde
/// está. Es la única regla de acceso de la app (la usa el `redirect` del router).
///
/// - **Sin sesión:** la primera vez ve el onboarding; después, el login.
/// - **Con sesión y suscripción activa:** entra directo (nunca ve el onboarding
///   ni el login, ni los planes salvo que los abra desde Ajustes).
/// - **Con sesión y sin suscripción:** solo ve la pantalla de planes (no hay plan
///   gratuito).
String? appRedirect({
  required bool isAuthenticated,
  required bool hasPlan,
  required bool onboardingCompleted,
  required String path,
}) {
  final isAuthRoute = _authRoutes.contains(path);
  final isOnboarding = path == '/onboarding';

  if (isAuthenticated) {
    final gate = subscriptionGateRedirect(
      isAuthenticated: true,
      hasPlan: hasPlan,
      path: path,
    );
    if (gate != null) return gate;
    return isAuthRoute || isOnboarding ? '/' : null;
  }

  if (!onboardingCompleted) return isOnboarding ? null : '/onboarding';
  return isAuthRoute ? null : '/login';
}
