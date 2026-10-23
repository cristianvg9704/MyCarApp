---
name: car-detail
description: Pantalla de detalle de vehículo con tabs (Detalle, Movimientos, Gráficos, Kilometraje). Úsalo al modificar esa pantalla, agregar tabs o cambiar qué datos muestra cada una.
---

# Detalle de vehículo

Ruta: `/car-detail?carId=<uuid>` → `CarDetailScreen` (`lib/screens/car_detail_screen.dart`).

## Estructura
`DefaultTabController` de 4 tabs en `AppBar.bottom`. Cada tab es una "pantalla" independiente
(solo se ve su contenido):

| Tab | Widget | Datos |
|---|---|---|
| Detalle | `CarInfoTab` (`lib/widgets/car_detail/car_info_tab.dart`) | `Car` (imagen, año, placa, color, compra, notas) |
| Movimientos | `CarTransactionsTab` | `List<CarTransaction>`, `isLoading`; filtro Todos/Ingresos/Egresos |
| Gráficos | `CarChartsTab` | `List<CarTransaction>`, `isLoading`; período 7/30/todos; ingresos, egresos, balance, barras por día y egresos por categoría |
| Kilometraje | `CarMileageTab` (`lib/widgets/car_mileage_tab.dart`) | usa `MileageProvider` y `TripProvider` |

El menú ⋮ del AppBar ofrece Editar (`VehicleModalHelper.showEditVehicleModal`) y Eliminar (`CarProvider.deleteCar`).

## Carga de datos
La pantalla carga el `Car` y luego sus movimientos (`DatabaseHelper.getCar`, `getTransactionsByCar`).
Ambos cargadores son inyectables (`carLoader`, `transactionsLoader`) para tests.

## Lógica pura
Ver skill `transactions` (`transaction_chart_utils.dart`, `currency_formatter.dart`).

## Tests
- `test/widgets/car_detail_screen_test.dart`: loader, no encontrado, 4 tabs, contenido por tab, estados vacíos.
- `test/utils/transaction_chart_utils_test.dart`: agrupación, resumen y límites de períodos.

## Pendiente / próximos cambios
- Registro por voz con el vehículo en contexto.
- Botón para registrar un movimiento desde el detalle del vehículo.
