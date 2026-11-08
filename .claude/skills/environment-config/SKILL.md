---
name: environment-config
description: Claves y configuración externa de la app (Supabase, RevenueCat, Google) en `.env` y cómo se cargan. Úsalo al añadir una clave o URL nueva, al tocar AppEnv/SupabaseConfig, al cambiar cómo se ejecuta o compila la app, o al configurar CI/builds de release.
---

# Configuración y claves (`.env`)

## Qué hace
Saca del código las claves y URLs que dependen del entorno. Se definen en `.env` (ignorado por git; plantilla
versionada en `.env.example`) y se inyectan al compilar con `--dart-define-from-file=.env`.

## Archivos y capas
- `.env.example` (versionado) y `.env` (local, nunca se commitea; `.gitignore` ignora `.env*` salvo el ejemplo).
- `lib/config/app_env.dart`: `AppEnv` con `String.fromEnvironment` para `SUPABASE_URL`, `SUPABASE_ANON_KEY`,
  `REVENUECAT_IOS_API_KEY`, `REVENUECAT_ANDROID_API_KEY`; `missing`/`missingMessage` para avisar de lo que falta.
- `lib/config/supabase_config.dart`: `initialize({url, anonKey})` lanza `StateError` claro si falta alguna.
- `lib/services/subscription_service.dart`: toma la clave de RevenueCat según plataforma; si está vacía no
  configura RevenueCat y avisa en el log.
- `lib/config/social_auth_config.dart`: `GOOGLE_WEB_CLIENT_ID` / `GOOGLE_IOS_CLIENT_ID` (mismo mecanismo).

## Reglas
- **No** usar un paquete que lea `.env` en runtime (p. ej. `flutter_dotenv`): empaqueta el archivo como asset y se
  puede extraer de la app. `dart-define` compila los valores y evita tener el archivo dentro del paquete.
- Toda clave nueva: añadirla a `.env.example`, a `AppEnv` y documentarla aquí. Nunca poner valores reales en el código
  ni en `.env.example`.
- Solo claves **públicas de cliente** (Supabase anon, SDK keys de RevenueCat, client IDs). **Nunca** la
  `service_role` de Supabase ni secretos de servidor en la app: viajan dentro del binario. Lo que protege los datos
  es RLS en Supabase, no ocultar la anon key.
- Los tests no usan `.env`: los que crean un cliente de Supabase usan `initSupabaseForTests()`
  (`test/helpers/supabase_test_init.dart`, valores falsos).

## Cómo se usa
- Ejecutar: `flutter run --dart-define-from-file=.env`. Release: `flutter build ios --release --dart-define-from-file=.env`
  (e instalar con `flutter install`). En VS Code las configuraciones de `launch.json` ya lo incluyen.
- Sin el flag la app arranca pero `SupabaseConfig.initialize` falla con `Falta configuración: …`.

## Cómo se prueba
`flutter test test/config/app_env_test.dart` (variables faltantes y error claro de Supabase). Manual: ejecutar con el
flag y comprobar `✅ Supabase inicializado correctamente`; sin el flag, el aviso de configuración.
