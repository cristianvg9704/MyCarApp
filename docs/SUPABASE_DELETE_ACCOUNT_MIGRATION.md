# Migración Supabase: eliminar cuenta

La app llama a la función `delete_my_account()` (RPC) para que el usuario borre su propia cuenta y todos sus datos
(requisito de Apple, guía 5.1.1(v)). No usa claves de servicio ni Edge Functions: la función corre con
`SECURITY DEFINER` y solo puede borrar al usuario que la invoca (`auth.uid()`).

Ejecuta este SQL en el **SQL Editor** de Supabase **antes** de publicar la versión con "Eliminar cuenta".

```sql
CREATE OR REPLACE FUNCTION public.delete_my_account()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth
AS $$
DECLARE
  uid uuid := auth.uid();
BEGIN
  IF uid IS NULL THEN
    RAISE EXCEPTION 'No autenticado';
  END IF;

  -- La tabla de alertas no está documentada: se borra explícitamente por si
  -- su clave foránea no tiene ON DELETE CASCADE.
  IF to_regclass('public.alerts') IS NOT NULL THEN
    DELETE FROM public.alerts WHERE user_id = uid;
  END IF;

  -- El resto (cars, car_transactions, mileage_readings, maintenance_logs,
  -- trip_logs) se elimina en cascada al borrar el usuario.
  DELETE FROM auth.users WHERE id = uid;
END;
$$;

REVOKE ALL ON FUNCTION public.delete_my_account() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.delete_my_account() TO authenticated;
```

## Qué se borra
Todas las tablas con `user_id REFERENCES auth.users(id) ON DELETE CASCADE`: vehículos, movimientos, lecturas de
kilometraje, mantenimientos y viajes. Si alguna otra tabla tuya referencia `auth.users` **sin** `ON DELETE CASCADE`,
la función fallará con un error de clave foránea: agrega un `DELETE` explícito para esa tabla antes del
`DELETE FROM auth.users`.

## Verificación
1. Crea un usuario de prueba con algunos datos e inicia sesión en la app.
2. Ajustes → Eliminar cuenta → escribe `ELIMINAR`.
3. En Supabase: `SELECT count(*) FROM auth.users WHERE email = '<correo de prueba>';` debe dar 0 y no deben quedar
   filas con su `user_id` en ninguna tabla.

## Suscripciones
Eliminar la cuenta **no cancela** una suscripción de App Store/Google Play. La app avisa al usuario en el diálogo
de confirmación para que la cancele desde los ajustes de su tienda.
