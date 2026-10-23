# Migración Supabase: ingresos y egresos

La tabla `incomes` pasa a llamarse `car_transactions` y guarda tanto ingresos como egresos.
Ejecuta este SQL en el **SQL Editor** de Supabase **antes** de usar la versión de la app con egresos
(la app consulta `car_transactions`; sin la migración, las pantallas de ingresos fallarán).

Es segura sobre datos existentes: los ingresos actuales quedan con `type = 'income'`. Las políticas RLS,
índices y claves foráneas se conservan al renombrar la tabla.

```sql
DO $$
BEGIN
  IF to_regclass('public.incomes') IS NOT NULL
     AND to_regclass('public.car_transactions') IS NULL THEN
    ALTER TABLE public.incomes RENAME TO car_transactions;
  END IF;
END $$;

ALTER TABLE public.car_transactions
  ADD COLUMN IF NOT EXISTS type TEXT NOT NULL DEFAULT 'income'
    CHECK (type IN ('income', 'expense')),
  ADD COLUMN IF NOT EXISTS liters NUMERIC(8, 2)
    CHECK (liters IS NULL OR liters > 0),
  ADD COLUMN IF NOT EXISTS odometer_km NUMERIC(10, 1)
    CHECK (odometer_km IS NULL OR odometer_km >= 0);

CREATE INDEX IF NOT EXISTS idx_car_transactions_car_type_date
  ON public.car_transactions(car_id, type, date);
```

## Columnas nuevas
| Columna | Uso |
|---|---|
| `type` | `income` o `expense` |
| `category` | para egresos: `fuel`, `maintenance`, `other` (ya existía; texto libre en ingresos antiguos) |
| `liters` | litros tanqueados (solo combustible, opcional) |
| `odometer_km` | kilometraje al momento del movimiento (combustible/mantenimiento, opcional) |

## Verificación
```sql
SELECT type, count(*) FROM public.car_transactions GROUP BY type;
```
Debe mostrar todos los registros existentes como `income`.
