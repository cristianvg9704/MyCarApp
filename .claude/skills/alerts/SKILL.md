---
name: alerts
description: Alertas y recordatorios de un vehículo (SOAT, revisión técnica, seguro, mantenimiento, personalizadas), su recurrencia y las notificaciones locales. Úsalo al tocar Alert, AlertProvider, AlertTemplates, las pantallas de alertas o NotificationService.
---

# Alertas

Recordatorio con fecha para un vehículo (`alerts` en Supabase, RLS por usuario). Puede repetirse (`daily`, `weekly`, `monthly`,
`yearly`, `custom_days`) y programa una notificación local (`NotificationService`).

## Archivos
| Capa | Archivo |
|---|---|
| Modelo | `lib/models/alert.dart` (`Alert`, `getNextRecurrenceDate`, `nextOccurrence`, `copyWith`) |
| Plantillas | `lib/services/alert_templates.dart` (SOAT, mantenimiento, revisión técnica, seguro, aceite, llantas, personalizada) |
| Estado | `lib/providers/alert_provider.dart` |
| Datos | `DatabaseHelper.insertAlert/updateAlert/completeAlert/...` |
| UI | `AlertsListScreen`, `AddAlertScreen`, `EditAlertScreen` |

## Completar una alerta recurrente
`AlertProvider.completeAlert` marca la alerta como completada y, si es recurrente, **inserta la siguiente ocurrencia** con
`Alert.nextOccurrence()` y le programa su notificación.

## Reglas y trampas
- **`copyWith(id: null)` NO borra el id**: usa `x ?? this.x`, así que `null` significa "conservar". Para crear una alerta nueva a
  partir de otra usa `nextOccurrence()` (o un constructor), nunca `copyWith` con `null`. Ese error hacía que completar una
  alerta recurrente fallara con `duplicate key value violates unique constraint "alerts_pkey"`.
- `DatabaseHelper.insertAlert` **no envía `id`**: insertar siempre crea una alerta nueva y el id lo genera la base de datos.
- La siguiente ocurrencia nace pendiente (`isCompleted: false`), sin `id`, `createdAt`, `updatedAt` ni `completedAt`.
- Conocido/pendiente: `getNextRecurrenceDate` ignora `recurrenceValue` en `monthly` y `yearly` (una plantilla de mantenimiento
  "cada 3 meses" avanza 1 mes), y `recurrenceCount` se copia sin decrementarse.

## Tests
`test/models/alert_test.dart`: `nextOccurrence` (sin id, pendiente, conserva la configuración, fechas por tipo, no recurrentes).
`AlertProvider` usa `DatabaseHelper` y `NotificationService` (singletons) y no se prueba directamente: la lógica que importa vive
en el modelo.
