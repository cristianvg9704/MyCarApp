---
name: trips
description: Viajes GPS (iniciar/detener, registro de km por ubicación) y su acceso rápido desde el inicio. Úsalo al tocar TripProvider, TripTrackingService, TripActions, HomeTripCard o la tarjeta de viaje de la pestaña Kilometraje.
---

# Viajes GPS

El usuario inicia un viaje, la app suma los km con GPS (también en segundo plano y con la pantalla apagada) y al
terminar guarda un `TripLog` y, si el usuario quiere, actualiza el odómetro. **Solo se inicia por acción del usuario**;
las coordenadas no se guardan ni se envían (solo distancia, duración y horas).

## Dónde se inicia/detiene
| Lugar | Widget | Notas |
|---|---|---|
| Inicio | `HomeTripCard` (`lib/widgets/home_trip_card.dart`) | Se muestra solo si hay vehículos. 1 vehículo → inicia directo; varios → hoja "¿Con qué vehículo vas a viajar?". Con viaje en curso muestra vehículo, distancia y duración en vivo (timer de 1 s solo mientras hay viaje), botón **Detener viaje**, y tocar la tarjeta abre `/car-detail?carId=` |
| Detalle del vehículo → Kilometraje | tarjeta en `CarMileageTab` | Misma lógica compartida |

Ambos usan `TripActions.start/stop` (`lib/widgets/trip_actions.dart`) para que avisos y diálogos sean idénticos.

## Capas y archivos
| Capa | Archivo |
|---|---|
| Servicio GPS | `lib/services/trip_tracking_service.dart` (`TripTrackingService`, `ActiveTripState`; persiste el viaje activo en `SharedPreferences`) |
| Estado | `lib/providers/trip_provider.dart` (`startTrip`, `stopTrip`, `liveTrip`, `isTracking`) |
| Acciones compartidas | `lib/widgets/trip_actions.dart` |
| Formato | `lib/utils/trip_format.dart` (`formatTripDuration`) |
| UI | `HomeTripCard`, `CarMileageTab` |
| Tabla | `trip_logs` (ver `docs/SUPABASE_MILEAGE_MIGRATION.md`) |

## Reglas
- Solo puede haber **un viaje activo** a la vez, de cualquier vehículo (`TripProvider.startTrip` lo rechaza si es de otro).
- Iniciar pide permiso de ubicación "Siempre"; si falla se muestra el motivo (`errorMessage`).
- Detener: sin distancia solo se cierra; con distancia se pregunta "Solo guardar viaje" / "Actualizar odómetro".
- Antes de detener desde el inicio se llama `MileageProvider.loadForCar(carId)` para que el odómetro actual sea el del
  vehículo del viaje.
- No hay widget nativo de pantalla de inicio del sistema (WidgetKit/App Widget): `HomeTripCard` es un widget **dentro de la
  app**. Un widget nativo requeriría targets nuevos de iOS/Android y App Intents.

## Tests
- `test/widgets/home_trip_card_test.dart`: oculto sin vehículos, iniciar con uno o varios vehículos, error de GPS, viaje en
  curso (datos en vivo), detener con y sin distancia, abrir el vehículo y refresco de la duración.
- `test/utils/trip_format_test.dart`.
- `TripTrackingService` (GPS real) no se prueba: verificar a mano en un dispositivo (iniciar, apagar la pantalla, detener).
