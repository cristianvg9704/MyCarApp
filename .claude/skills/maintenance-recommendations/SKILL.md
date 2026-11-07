---
name: maintenance-recommendations
description: Recomendaciones de mantenimiento y métricas de uso (km/día, rendimiento km/L, costo por km) derivadas del historial del propietario, sin intervalos predefinidos. Úsalo al tocar MaintenanceRecommendationService, UsageAnalytics, MileageProvider o la tab Kilometraje.
---

# Recomendaciones de mantenimiento desde el historial

Las recomendaciones NO usan valores predefinidos. Todo sale de lo que el dueño registró:
lecturas de odómetro (`mileage_readings`), servicios (`maintenance_logs`) y egresos de
combustible/mantenimiento con odómetro (`car_transactions`). Solo las etiquetas de nombre
(`serviceTypeLabels`) son estáticas; los intervalos nunca.

## Capas y archivos
| Capa | Archivo | Rol |
|---|---|---|
| Modelo | `lib/models/maintenance_recommendation.dart` | `MaintenanceRecommendation`, `MaintenanceStatus` (ok / soon / overdue / needsHistory) |
| Lógica pura | `lib/services/usage_analytics.dart` | `UsageAnalytics`: puntos de odómetro, km/día, km/L, costo por km, costo medio de mantenimiento; `UsageInsights` |
| Lógica pura | `lib/services/maintenance_recommendation_service.dart` | `buildRecommendations(currentOdometerKm, maintenanceLogs, now, kmPerDay)`, `median`, `labelFor`, `calculateTrackedKm` |
| Datos | `lib/services/mileage_repository.dart` | `MileageRepository` (abstracto) + `SupabaseMileageRepository` |
| Estado | `lib/providers/mileage_provider.dart` | Carga datos, calcula `insights` y `recommendations`; `repository` y `clock` inyectables |
| UI | `lib/widgets/car_mileage_tab.dart` | Tarjeta "Tu uso", tarjetas de recomendación, botones Registrar km / Servicio |

## Reglas de negocio
- **Un tipo de servicio sin registros no genera recomendación.**
- **1 registro** → estado `needsHistory` ("Falta historial"): se muestra último servicio y lo transcurrido (días/km); no hay intervalo ni fecha estimada.
- **2+ registros** → intervalo propio = **mediana** de los km y de los días entre servicios consecutivos (ignora deltas <= 0; la mediana resiste un servicio olvidado mucho tiempo). Si solo una dimensión tiene deltas positivos, se usa solo esa. Si ninguna, `needsHistory`.
- `kmRemaining = intervalKm - kmSinceService`; `daysRemaining = intervalDays - daysSinceService`.
- Estado: `overdue` si cualquiera <= 0; `soon` si queda <= 20% (`soonFraction`) del intervalo en km o días; si no `ok`.
- **Fecha estimada** = hoy + lo primero entre `daysRemaining` y `kmRemaining / kmPerDay` (km/día reales). Vencido → hoy. Sin km/día solo cuenta el intervalo en días.
- Orden: vencido, próximo, al día, falta historial; dentro de cada grupo por fecha estimada.

### Métricas (`UsageAnalytics`)
- **Puntos de odómetro**: lecturas + servicios + egresos de combustible/mantenimiento con `odometer_km`, ordenados por fecha; valores que retroceden se descartan (errores de captura), los iguales se conservan.
- **km/día** = (último km - primer km) / días entre ambos. Requiere >= 2 puntos, lapso >= 7 días (`minSpanDaysForRate`) y avance > 0; si no, null.
- **Rendimiento km/L**: egresos de combustible con odómetro y litros, ordenados por odómetro; km entre tanqueadas consecutivas / litros de la segunda (método tanque lleno). Pares sin avance se ignoran. Null con < 2 tanqueadas válidas.
- **Costo por km**: egresos de combustible + mantenimiento fechados después del primer punto y hasta el último / km recorridos en ese lapso.
- **Costo promedio de mantenimiento**: media de egresos con categoría `maintenance`.
- El odómetro actual (`MileageProvider.currentOdometerKm`) es el último punto coherente de todas las fuentes.

## UI (tab Kilometraje, sin rediseño)
- Tarjeta "Tu uso (según tu historial)" solo con las métricas que tienen datos.
- Botón **Servicio** abre un diálogo (tipo, odómetro, fecha) → `MileageProvider.addMaintenanceLog`. Es la forma de crear el historial de cada servicio; "Marcar como hecho" en una tarjeta registra otro servicio del mismo tipo al odómetro actual.
- Sin servicios registrados: estado vacío que explica que con 2 registros se calcula el intervalo real.

## Limitaciones conocidas
- Los egresos de mantenimiento de `car_transactions` no tienen tipo de servicio, por eso solo aportan odómetro y costos, no intervalos por tipo. Asociarlos requeriría una columna nueva (no implementada; no se hizo ningún cambio de esquema).
- El odómetro actual es el último dato registrado; si es antiguo, `kmSinceService` queda subestimado hasta que se registre uno nuevo.
- Los viajes GPS (`trip_logs`) alimentan el odómetro solo cuando el usuario actualiza el odómetro (crea una lectura); no se cuentan aparte para no duplicar km.

## Tests
- `test/services/usage_analytics_test.dart`: fusión y limpieza de puntos, km/día, km/L, costo por km, costo medio, `compute`.
- `test/services/maintenance_recommendation_service_test.dart`: 0/1/2+ registros, mediana, vencido/próximo/al día, proyección por km/día vs días, deltas degenerados, orden.
- `test/providers/mileage_provider_test.dart`: carga con repositorio falso, fallo de movimientos no bloqueante, validación de odómetro, alta de servicios con reloj inyectado.
