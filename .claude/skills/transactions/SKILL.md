---
name: transactions
description: Movimientos económicos de un vehículo (ingresos y egresos: combustible, mantenimiento, otros). Úsalo al tocar el modelo CarTransaction, su tabla de Supabase, el formulario de registro, las pantallas de Finanzas, el formateador COP o los gráficos de ingresos/egresos.
---

# Movimientos (ingresos y egresos)

Un solo concepto para plata: `CarTransaction` (`lib/models/car_transaction.dart`), guardado en la tabla
Supabase `car_transactions` (antes `incomes`). Migración: `docs/SUPABASE_TRANSACTIONS_MIGRATION.md`
(el usuario la ejecuta en el SQL Editor; sin ella la app falla al consultar `car_transactions`).

## Modelo
- `type`: `TransactionType.income | expense`. `amount` siempre positivo; el signo lo da `type` (`signedAmount`).
- `category` (`TransactionCategory`: `fuel`, `maintenance`, `other`) solo aplica a egresos. Valores desconocidos
  (texto libre de ingresos antiguos) se leen como `null`.
- `liters` (solo combustible) y `odometerKm` (combustible/mantenimiento) son opcionales.
- Filas sin `type` se leen como ingreso (compatibilidad).

## Capas
| Capa | Archivo |
|---|---|
| Acceso a datos | `TransactionRepository` + `SupabaseTransactionRepository` (`lib/services/transaction_repository.dart`) sobre `DatabaseHelper.*Transaction*` |
| Estado | `TransactionProvider` (`lib/providers/transaction_provider.dart`): `loadByCar`, `add`, `update`, `delete` (recarga el auto seleccionado) |
| Registro | `AddTransactionScreen` (`lib/screens/add_transaction_screen.dart`) y `TransactionModalHelper.showAddTransactionModal(context, {carId, initialType})` |
| Finanzas | `FinancesListScreen` (tab "Finanzas": balance/ingresos/egresos por vehículo), `CarFinancesScreen` (`/car-incomes?carId=`, historial + resumen) |
| Detalle de vehículo | tabs "Movimientos" y "Gráficos" (ver skill `car-detail`) |
| UI | `TransactionTile` (`lib/widgets/transaction_tile.dart`): verde `+` ingresos, rojo `-` egresos |

## Formulario de registro
- Selector Ingreso/Egreso; si es egreso, chips de categoría (por defecto Combustible).
- Combustible: litros + kilometraje opcionales. Mantenimiento: kilometraje opcional. Otros: nada extra.
- Descripción obligatoria en ingresos; en egresos es opcional y por defecto toma el nombre de la categoría.
- Los campos de combustible/odómetro se descartan si la categoría ya no los usa.
- `currentUserId` es inyectable (default: usuario de Supabase) para poder probar.

## Dinero (COP)
`lib/utils/currency_formatter.dart`:
- `CurrencyFormatter.format(x)` → `$1.234.567` (sin decimales, punto de miles); `formatSigned` agrega `+`/`-`.
- `parseAmount(text)` interpreta lo que escribe el usuario: `50000`, `50.000`, `1.234,56`, `12,5`.
  Un único separador seguido de exactamente 3 dígitos cuenta como miles.
- Usar siempre estas funciones; no formatear con `NumberFormat` suelto. Otras monedas (USD) y i18n: pendiente.

## Cálculos (`lib/utils/transaction_chart_utils.dart`)
`filterByPeriod`, `groupTransactionsByDay` (→ `DayTotals`), `TransactionSummary.of` (ingresos, egresos, balance,
egresos por categoría). Funciones puras, `now` inyectable.

## Tests
`test/models/car_transaction_test.dart`, `test/utils/transaction_chart_utils_test.dart`,
`test/utils/currency_formatter_test.dart`, `test/providers/transaction_provider_test.dart` (repositorio falso),
`test/widgets/add_transaction_screen_test.dart`, `test/widgets/car_detail_screen_test.dart`,
`test/widgets/finances_list_screen_test.dart`.

## Pendiente
- Registro por voz (STT del dispositivo + parser local; IA más adelante) reutilizando `parseAmount` y `CarTransaction`.
- Recomendaciones de mantenimiento basadas en el historial (usa egresos de mantenimiento/combustible y `odometerKm`).
- Editar/eliminar un movimiento desde la UI (el provider ya soporta `update`/`delete`).
- Enlazar egresos de mantenimiento con `MaintenanceLog` y guardar el odómetro como lectura de kilometraje.
