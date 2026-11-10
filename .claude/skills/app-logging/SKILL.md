---
name: app-logging
description: Logs de la app (solo en debug, silenciados en release). Úsalo al agregar logs, tocar configureLogging/main.dart o al depurar el consumo de notificaciones y alertas.
---

# Logs solo en debug

`debugPrint` **imprime también en builds release**, así que `configureLogging()`
(`lib/utils/app_logging.dart`, llamado al inicio de `main()`) lo reemplaza por una función vacía cuando
`kReleaseMode` es true. En debug/profile no se toca.

## Reglas
- Usa siempre `debugPrint`, **nunca `print`** (no lo cubre el silenciador; el lint `avoid_print` lo marca).
- No loguees datos sensibles (tokens, contraseñas, correos) ni siquiera en debug.
- No hay timers que consulten estado solo para escribir logs. El antiguo monitor de notificaciones pendientes
  (cada 20 s) se eliminó; para inspeccionarlas usa `NotificationService.getPendingNotifications()` puntualmente.

## Pendiente
- Reemplazar los `debugPrint` dispersos por un logger con niveles (`info`/`warning`/`error`) y, para release,
  un servicio de reporte de errores (Crashlytics/Sentry).

## Tests
`test/utils/app_logging_test.dart`: en release descarta `debugPrint`; en debug no lo toca.
