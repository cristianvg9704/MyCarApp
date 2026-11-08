---
name: social-auth
description: Iniciar sesión o registrarse con Apple y Google (SDK nativos + Supabase signInWithIdToken). Úsalo al tocar los botones sociales, SocialAuthService, AuthProvider.signInWithSocial, la configuración de Google/Apple o los permisos de plataforma.
---

# Login con Apple y Google

Los botones **Continuar con Apple / Google** aparecen en `LoginScreen` y `RegisterScreen`. El mismo flujo inicia sesión o crea
la cuenta (Supabase crea el usuario la primera vez). La configuración externa (Apple Developer, Google Cloud, Supabase) está en
`docs/SOCIAL_AUTH_SETUP.md`.

## Flujo
1. `SocialAuthButtons` (`lib/widgets/social_auth_buttons.dart`) muestra el separador y los botones. Apple usa el botón oficial
   (`SignInWithAppleButton`) y solo se ofrece donde existe (iOS/macOS); Google en iOS y Android.
   Todos los botones de la pantalla de login (incluido "Iniciar sesión") miden 52 de alto con esquinas de 14;
   si cambias uno, cambia los demás (lo cubre `login_screen_test.dart`).
2. La pantalla llama `AuthProvider.signInWithSocial(provider)`.
3. `AuthProvider` delega en `SocialAuthService` (inyectable: `AuthProvider(socialAuthService: ...)`).
4. `DeviceSocialAuthService` (`lib/services/social_auth_service.dart`):
   - **Apple:** genera un nonce (`generateRawNonce`), envía su SHA-256 a Apple y el valor original a Supabase; guarda el nombre
     (solo llega la primera vez) en `user_metadata.name`.
   - **Google:** `GoogleSignIn.instance.initialize(clientId, serverClientId)` + `authenticate()`; usa el `idToken`.
   - Ambos terminan en `supabase.auth.signInWithIdToken(...)`.
5. Resultado: `signedIn` → la pantalla va a `goAfterSignIn` (`lib/utils/auth_navigation.dart`: suscripción la primera vez, luego
   home). `cancelled` → no hace nada y no muestra error. `SocialAuthException` → su mensaje en español. Otro error → mensaje genérico.

## Configuración en la app
`lib/config/social_auth_config.dart`: `GOOGLE_WEB_CLIENT_ID` (obligatorio, el mismo que Supabase) y `GOOGLE_IOS_CLIENT_ID` (iOS),
vía `--dart-define` o valor por defecto. Sin el Web client ID, el botón de Google muestra "aún no está configurado".

## Plataforma (manual, no está en el código)
- iOS: capability **Sign in with Apple** en Xcode; esquema de URL con el *reversed client ID* de Google en `Info.plist`.
- Android: cliente OAuth de tipo Android con el SHA-1 de la firma.
- Tras agregar los plugins hay que recompilar por completo (`pod install` en iOS).

## Reglas
- No guardar tokens ni secretos en el repositorio; los client IDs se pasan al compilar.
- Cualquier proveedor social nuevo se agrega a `SocialProvider`, a `DeviceSocialAuthService` y a `SocialAuthButtons`.
- Si se agrega un proveedor social, Apple exige mantener "Iniciar sesión con Apple" junto a él.

## Tests
- `test/providers/auth_provider_social_test.dart`: éxito, cancelación, errores, mensajes sin detalle técnico, disponibilidad.
- `test/services/social_auth_service_test.dart`: disponibilidad por plataforma y errores cuando falta configuración.
- `test/utils/nonce_utils_test.dart`: nonce y SHA-256.
- `test/widgets/social_auth_buttons_test.dart` y `test/widgets/login_social_auth_test.dart`: botones y flujos de la pantalla de login.
- No cubierto: las llamadas reales a los SDK de Apple/Google y a Supabase; probar a mano en dispositivo con las cuentas configuradas.

## Pendiente
- Revocar el token de Apple al eliminar la cuenta (ver `account-deletion` y `docs/SOCIAL_AUTH_SETUP.md`): requiere una Edge Function.
- Pedir el teléfono tras un registro social, si se necesita (hoy solo se pide en el registro con correo).
