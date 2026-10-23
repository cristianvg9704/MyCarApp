---
name: ui-system
description: Sistema de UI de MyCar (Material 3). Úsalo al crear o modificar cualquier pantalla o widget: colores, tarjetas, estados vacíos, métricas y estructura de pantallas con tabs.
---

# UI system de MyCar

Base: Material 3 (`useMaterial3: true`) con tema en `lib/utils/app_theme.dart` y paleta en
`lib/utils/my_car_colors.dart`. La app es multiplataforma: usar widgets Material; solo usar
variantes `.adaptive` (Switch, diálogos) cuando se quiera comportamiento nativo en iOS.

## Reglas
- Colores siempre de `MyCarColors` (`primary`, `secondary`, `success`, `error`, `warning`,
  `textPrimary/Secondary/Tertiary`, `border`, `backgroundLight`). No hardcodear `Color(0x...)` ni `Colors.red/green`
  en pantallas nuevas (los existentes se migran de a poco).
- Tipografía desde `Theme.of(context).textTheme`; solo ajustar `fontWeight`/`color` con `copyWith`.
- Fondo de pantalla: `MyCarColors.backgroundLight`; superficies (tarjetas) blancas con radio 12–16
  y borde `MyCarColors.border` (o sombra suave `black @ 0.08`).
- Padding horizontal de contenido: 16. Padding inferior de listas/scroll:
  `MediaQuery.of(context).padding.bottom + 40`.
- Ingresos/positivo → `MyCarColors.success`; egresos/negativo → `MyCarColors.error`.
- Textos de UI en español por ahora (i18n en inglés queda pendiente).
- Dinero: siempre `CurrencyFormatter` (COP, `$1.234.567`); ver skill `transactions`. Ingresos en verde, egresos en rojo.

## Componentes reutilizables (`lib/widgets/`)
- `EmptyState(icon, title, message)` — estado vacío centrado.
- `StatCard(label, value, icon, {valueColor})` — métrica con etiqueta e icono.
- `TransactionTile(transaction)` — fila de ingreso/egreso con signo y color.
- `myCarInputDecoration(...)` / `myCarInputTextStyle` (`lib/utils/form_decoration.dart`) — campos de formulario.
- Tabs de detalle de vehículo en `lib/widgets/car_detail/` (ver skill `car-detail`).

Antes de crear un widget nuevo, revisa si ya existe uno aquí; si un patrón se usa en 2+ pantallas, extráelo.

## Testabilidad de UI
- Pantallas con datos externos reciben **cargadores inyectables** por constructor
  (`carLoader`, `transactionsLoader`, `repository`) con default a `DatabaseHelper`. Los tests pasan funciones falsas.
- Widgets de tab son "tontos": reciben datos y `isLoading`, no acceden a Supabase.
- Lógica de cálculo (agrupar, filtrar, formatear) va en `lib/utils/` como funciones puras con `now` inyectable.
