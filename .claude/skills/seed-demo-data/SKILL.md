---
name: seed-demo-data
description: Script que carga datos de demostración (vehículos, kilometraje, mantenimiento, movimientos, viajes y alertas) en la cuenta de un usuario de Supabase. Úsalo al preparar una cuenta de prueba para capturas, TestFlight o la revisión de Apple, o al cambiar el esquema de alguna tabla que el script inserta.
---

# Datos de demostración

## Qué hace
`tool/seed_demo_data.dart` inicia sesión con correo y contraseña (igual que la app) y inserta por la
API REST de Supabase con el token del usuario. **Respeta RLS y no usa `service_role`.** No es una
migración ni parte de la app: es una herramienta de desarrollo.

## Uso
Desde la raíz del proyecto, con `.env` (necesita `SUPABASE_URL` y `SUPABASE_ANON_KEY`):

```bash
dart run tool/seed_demo_data.dart --email tu@correo.com --password '...'   # borra la demo anterior y crea datos
dart run tool/seed_demo_data.dart --email tu@correo.com --password '...' --reset   # solo borra la demo
```
También acepta `SEED_EMAIL` / `SEED_PASSWORD` como variables de entorno y `--env <archivo>`.
**No guardes la contraseña en el repo ni en scripts versionados.** El correo de la cuenta debe estar
confirmado en Supabase.

## Qué crea
Tres vehículos escogidos para mostrar todos los estados de las recomendaciones de mantenimiento:

| Placa | Vehículo | Qué ilustra |
|---|---|---|
| `MZD321` | Mazda 3 2021 (~46 mil km, 330 días de historial) | Cambio de aceite **al día**, filtro de aire **próximo**, frenos **falta historial**, ingresos semanales de plataforma, 18 viajes |
| `SPK918` | Chevrolet Spark 2018 (~89 mil km) | Cambio de aceite **vencido**, alerta de SOAT **vencida** |
| `RDS452` | Renault Duster 2023 (~7 mil km, 120 días) | Poco historial, un solo servicio |

Cada vehículo recibe lecturas de odómetro (cada ~2 semanas), servicios con su egreso de
mantenimiento, tanqueadas con litros coherentes con un rendimiento real (km/L), gastos varios
(parqueadero, lavado, peajes, impuesto), viajes de los últimos 30 días y alertas (SOAT, revisión
técnica, seguro, mantenimiento y una completada).

## Reglas
- **Idempotente:** antes de insertar borra los vehículos del usuario con las placas de
  `DemoDataGenerator.demoPlates`; el resto de su historial sale por `ON DELETE CASCADE`.
  **Los vehículos reales del usuario no se tocan** (nunca uses esas placas en cuentas reales).
- Las fechas son relativas a "hoy", así que los estados (vencido/próximo) se mantienen al re-ejecutar.
- El odómetro nunca retrocede (si no, `UsageAnalytics` descarta los puntos).
- Se omiten los `null` al insertar para que apliquen los `DEFAULT` de la base de datos.

## Capas y archivos
| Archivo | Rol |
|---|---|
| `tool/seed/demo_data_generator.dart` | `DemoDataGenerator`: lógica pura y determinista (seed, `now` y `newId` inyectables). Usa los modelos de `lib/models` (`toMap`) para no desviarse del esquema |
| `tool/seed_demo_data.dart` | CLI: argumentos, lectura de `.env`, Auth + PostgREST con `package:http` |
| `test/tool/demo_data_generator_test.dart` | Tests del generador |

## Tablas que escribe
`cars`, `mileage_readings`, `maintenance_logs`, `car_transactions`, `trip_logs`, `alerts`. Si cambia
una columna en alguna, actualiza el modelo y el generador y ejecuta los tests.

## Cómo se prueba
`flutter test test/tool`. Cubre: ids únicos y consistentes, odómetro creciente, nada en el futuro,
combustible/viajes coherentes, alertas vencida/completada y que las recomendaciones salgan en los
estados esperados (al día, próximo, vencido, falta historial). El envío a Supabase se verifica
ejecutando el script contra una cuenta real.
