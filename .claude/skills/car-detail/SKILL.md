---
name: car-detail
description: Pantalla de detalle de vehículo con tabs (Detalle, Ingresos, Gráficos, Kilometraje). Úsalo al modificar esa pantalla, agregar tabs o cambiar qué datos muestra cada una.
---

# Detalle de vehículo

Ruta: `/car-detail?carId=<uuid>` → `CarDetailScreen` (`lib/screens/car_detail_screen.dart`).

## Estructura
`DefaultTabController` de 4 tabs en `AppBar.bottom`. Cada tab es una "pantalla" independiente
(solo se ve su contenido):

| Tab | Widget | Datos |
|---|---|---|
| Detalle | `CarInfoTab` (`lib/widgets/car_detail/car_info_tab.dart`) | `Car` (imagen, año, placa, color, compra, notas) |
| Ingresos | `CarIncomesTab` | `List<Income>`, `isLoading` |
| Gráficos | `CarChartsTab` | `List<Income>`, `isLoading`; período 7/30/todos |
| Kilometraje | `CarMileageTab` (`lib/widgets/car_mileage_tab.dart`) | usa `MileageProvider` y `TripProvider` |

El menú ⋮ del AppBar ofrece Editar (`VehicleModalHelper.showEditVehicleModal`) y Eliminar (`CarProvider.deleteCar`).

## Carga de datos
La pantalla carga el `Car` y luego sus ingresos (`DatabaseHelper.getCar`, `getIncomesByCar`).
Ambos cargadores son inyectables (`carLoader`, `incomesLoader`) para tests.

## Lógica pura
`lib/utils/income_chart_utils.dart`: `groupIncomesByDay(incomes, ChartPeriod, {now})` suma por día
y filtra por período (7 = hoy + 6 días previos; 30 = hoy + 29; all = sin filtro; ignora futuros en 7/30).

## Tests
- `test/widgets/car_detail_screen_test.dart`: loader, no encontrado, 4 tabs, contenido por tab, estados vacíos.
- `test/utils/income_chart_utils_test.dart`: agrupación y límites de períodos.

## Pendiente / próximos cambios
- Agregar egresos (combustible, mantenimiento) a las tabs Ingresos y Gráficos.
- Registro por voz con el vehículo en contexto.
