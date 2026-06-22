# Arquitectura Tenant con Row Level Security (RLS) en Supabase

## Resumen

Este documento describe la arquitectura propuesta para implementar multi-tenancy en la aplicación MyCar usando Row Level Security (RLS) de Supabase. Esta arquitectura garantiza que cada usuario solo pueda acceder a sus propios datos de forma segura y automática.

## ¿Por qué RLS?

Row Level Security (RLS) es la solución nativa de Supabase para multi-tenancy. Ofrece:

- **Seguridad a nivel de base de datos**: Las políticas se aplican directamente en PostgreSQL
- **Automático**: No requiere filtrar manualmente en cada query de la app
- **Escalable**: Funciona con millones de usuarios sin problemas de rendimiento
- **Seguro**: Imposible acceder a datos de otros usuarios, incluso si se manipula el código del cliente

## Estructura de Base de Datos

### Tabla: `cars`

```sql
CREATE TABLE public.cars (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  brand TEXT NOT NULL,
  model TEXT NOT NULL,
  year INTEGER NOT NULL,
  plate_number TEXT,
  color TEXT,
  purchase_date TIMESTAMPTZ,
  purchase_price DECIMAL(10, 2),
  notes TEXT,
  image_path TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Índice para mejorar rendimiento de queries por usuario
CREATE INDEX idx_cars_user_id ON public.cars(user_id);
```

### Tabla: `incomes`

```sql
CREATE TABLE public.incomes (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  car_id UUID NOT NULL REFERENCES public.cars(id) ON DELETE CASCADE,
  description TEXT NOT NULL,
  amount DECIMAL(10, 2) NOT NULL,
  date TIMESTAMPTZ NOT NULL,
  category TEXT,
  notes TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Índices para mejorar rendimiento
CREATE INDEX idx_incomes_user_id ON public.incomes(user_id);
CREATE INDEX idx_incomes_car_id ON public.incomes(car_id);
CREATE INDEX idx_incomes_date ON public.incomes(date DESC);
```

## Políticas RLS

### Habilitar RLS en las tablas

```sql
-- Habilitar RLS en ambas tablas
ALTER TABLE public.cars ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.incomes ENABLE ROW LEVEL SECURITY;
```

### Políticas para `cars`

```sql
-- Los usuarios solo pueden ver sus propios carros
CREATE POLICY "Users can view their own cars"
  ON public.cars
  FOR SELECT
  USING (auth.uid() = user_id);

-- Los usuarios solo pueden insertar carros para sí mismos
CREATE POLICY "Users can insert their own cars"
  ON public.cars
  FOR INSERT
  WITH CHECK (auth.uid() = user_id);

-- Los usuarios solo pueden actualizar sus propios carros
CREATE POLICY "Users can update their own cars"
  ON public.cars
  FOR UPDATE
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

-- Los usuarios solo pueden eliminar sus propios carros
CREATE POLICY "Users can delete their own cars"
  ON public.cars
  FOR DELETE
  USING (auth.uid() = user_id);
```

### Políticas para `incomes`

```sql
-- Los usuarios solo pueden ver sus propios ingresos
CREATE POLICY "Users can view their own incomes"
  ON public.incomes
  FOR SELECT
  USING (auth.uid() = user_id);

-- Los usuarios solo pueden insertar ingresos para sí mismos
CREATE POLICY "Users can insert their own incomes"
  ON public.incomes
  FOR INSERT
  WITH CHECK (auth.uid() = user_id);

-- Los usuarios solo pueden actualizar sus propios ingresos
CREATE POLICY "Users can update their own incomes"
  ON public.incomes
  FOR UPDATE
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

-- Los usuarios solo pueden eliminar sus propios ingresos
CREATE POLICY "Users can delete their own incomes"
  ON public.incomes
  FOR DELETE
  USING (auth.uid() = user_id);
```

## Migración desde SQLite Local

### Paso 1: Crear tablas en Supabase

Ejecutar los scripts SQL anteriores en el SQL Editor de Supabase.

### Paso 2: Modificar DatabaseHelper

Cambiar de SQLite local a Supabase Client:

```dart
// Antes (SQLite local)
final db = await database;
await db.insert('cars', car.toMap());

// Después (Supabase)
await SupabaseConfig.client
  .from('cars')
  .insert(car.toMap());
```

### Paso 3: Actualizar modelos

Agregar `user_id` a los modelos y métodos `toMap()`:

```dart
class Car {
  final String? id;  // Cambiar de int? a String? (UUID)
  final String userId;  // NUEVO
  // ... otros campos
}
```

### Paso 4: Migración de datos (opcional)

Si hay datos locales que migrar:

```dart
// 1. Obtener datos locales
final localCars = await localDbHelper.getAllCars();

// 2. Obtener user_id del usuario autenticado
final userId = SupabaseConfig.client.auth.currentUser?.id;

// 3. Insertar en Supabase con user_id
for (final car in localCars) {
  await SupabaseConfig.client
    .from('cars')
    .insert({
      ...car.toMap(),
      'user_id': userId,
    });
}
```

## Ventajas de esta Arquitectura

1. **Seguridad**: Imposible acceder a datos de otros usuarios
2. **Simplicidad**: No necesitas filtrar manualmente en cada query
3. **Rendimiento**: Los índices y políticas están optimizados
4. **Escalabilidad**: Funciona con millones de usuarios
5. **Mantenibilidad**: Las políticas están centralizadas en la base de datos

## Consideraciones

1. **user_id automático**: Con RLS, siempre debes incluir `user_id` en los inserts, pero las políticas garantizan que solo puedas usar tu propio ID.

2. **Foreign Keys**: La relación `car_id` en `incomes` también está protegida porque solo puedes referenciar carros que te pertenecen (gracias a RLS).

3. **Cascading Deletes**: Si eliminas un usuario, todos sus carros e ingresos se eliminan automáticamente gracias a `ON DELETE CASCADE`.

4. **Testing**: En desarrollo, puedes deshabilitar temporalmente RLS para pruebas, pero NUNCA en producción.

## Próximos Pasos

1. ✅ Crear tablas en Supabase con el esquema propuesto
2. ✅ Implementar políticas RLS
3. ✅ Migrar `DatabaseHelper` para usar Supabase Client
4. ✅ Actualizar modelos para incluir `user_id`
5. ✅ Migrar datos locales (si aplica)
6. ✅ Probar que RLS funciona correctamente
7. ✅ Remover código de SQLite local una vez migrado completamente

## Referencias

- [Supabase RLS Documentation](https://supabase.com/docs/guides/auth/row-level-security)
- [PostgreSQL RLS](https://www.postgresql.org/docs/current/ddl-rowsecurity.html)
