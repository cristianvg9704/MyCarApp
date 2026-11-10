---
name: ui-system
description: Sistema de UI de MyCar (Material 3). Úsalo al crear o modificar cualquier pantalla o widget: colores, tarjetas, estados vacíos, métricas y estructura de pantallas con tabs.
---

# UI system de MyCar

Base: Material 3 (`useMaterial3: true`) con tema en `lib/utils/app_theme.dart` y paleta en
`lib/utils/my_car_colors.dart`. La app es multiplataforma: usar widgets Material; solo usar
variantes `.adaptive` (Switch, diálogos) cuando se quiera comportamiento nativo en iOS.

## Reglas
- **Colores (modo claro y oscuro):**
  - Colores de **marca y estado** (`MyCarColors.primary`, `secondary`, `success`, `error`, `warning`, `primaryGradient`) se usan
    directo: se ven bien en ambos modos (sobre todo como fondo de botón o borde).
  - Colores que **dependen del fondo** (texto, bordes, superficies, tintes) se leen del tema: `context.palette.textPrimary`,
    `textSecondary`, `textTertiary`, `textLabel`, `border`, `borderLight`, `background` (tarjetas, hojas, diálogos),
    `backgroundLight` (fondo de pantalla), `surfaceMuted`, `primaryLight`, `primarySoft`, `secondaryLight`, `income`,
    `expense` (y sus `*Light`). **Nunca** `MyCarColors.textPrimary`/`border`/`background`… ni `Colors.white`/`Colors.grey` como
    fondo o texto de UI: en modo oscuro quedan texto casi negro sobre fondo oscuro. Un test lo impide.
  - Índigo o azul como **texto o ícono** sobre una superficie: `context.palette.accent` / `accentSecondary` (más claros en oscuro;
    `#4F46E5` sobre gris oscuro solo contrasta 2,3:1). `Colors.white` sí es válido para texto/íconos sobre un fondo de color
    (botones índigo, degradado del encabezado).
  - La paleta está en `lib/utils/my_car_palette.dart` (`MyCarPalette.light/dark`, `ThemeExtension`); `AppTheme` la registra y
    alinea `ColorScheme`, diálogos, hojas, snackbars, botones de texto y pestañas en oscuro. Sin `AppTheme` (tests con un
    `MaterialApp` pelado) `context.palette` cae a la clara.
  - Como leen el tema, estos widgets **no pueden ser `const`**.
  - No hardcodear `Color(0x...)` ni `Colors.red/green` en pantallas nuevas.
  - Al crear una pantalla, agrégala a `test/widgets/dark_mode_test.dart`: renderiza con el tema oscuro y falla si algún texto
    contrasta menos de 3:1 con su fondo.
- Tipografía desde `Theme.of(context).textTheme`; solo ajustar `fontWeight`/`color` con `copyWith`.
- Fondo de pantalla: `context.palette.backgroundLight`; superficies (tarjetas) `context.palette.background` con radio 12–16
  y borde `context.palette.border` (o sombra suave `black @ 0.08`).
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
