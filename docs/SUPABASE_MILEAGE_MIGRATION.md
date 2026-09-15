# Migración Supabase: Kilometraje y mantenimiento

Ejecuta este SQL en el **SQL Editor** de Supabase antes de usar el feature de kilometraje.

```sql
-- Lecturas del odómetro
CREATE TABLE IF NOT EXISTS public.mileage_readings (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  car_id UUID NOT NULL REFERENCES public.cars(id) ON DELETE CASCADE,
  odometer_km NUMERIC(10, 1) NOT NULL CHECK (odometer_km >= 0),
  reading_date DATE NOT NULL,
  notes TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_mileage_readings_car_id
  ON public.mileage_readings(car_id);

CREATE INDEX IF NOT EXISTS idx_mileage_readings_user_id
  ON public.mileage_readings(user_id);

-- Historial de mantenimientos realizados
CREATE TABLE IF NOT EXISTS public.maintenance_logs (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  car_id UUID NOT NULL REFERENCES public.cars(id) ON DELETE CASCADE,
  service_type TEXT NOT NULL,
  odometer_km NUMERIC(10, 1) NOT NULL CHECK (odometer_km >= 0),
  service_date DATE NOT NULL,
  notes TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_maintenance_logs_car_id
  ON public.maintenance_logs(car_id);

CREATE INDEX IF NOT EXISTS idx_maintenance_logs_user_id
  ON public.maintenance_logs(user_id);

ALTER TABLE public.mileage_readings ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.maintenance_logs ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view their own mileage readings"
  ON public.mileage_readings FOR SELECT
  USING (auth.uid() = user_id);

CREATE POLICY "Users can insert their own mileage readings"
  ON public.mileage_readings FOR INSERT
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can delete their own mileage readings"
  ON public.mileage_readings FOR DELETE
  USING (auth.uid() = user_id);

CREATE POLICY "Users can view their own maintenance logs"
  ON public.maintenance_logs FOR SELECT
  USING (auth.uid() = user_id);

CREATE POLICY "Users can insert their own maintenance logs"
  ON public.maintenance_logs FOR INSERT
  WITH CHECK (auth.uid() = user_id);

-- Viajes GPS registrados automáticamente
CREATE TABLE IF NOT EXISTS public.trip_logs (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  car_id UUID NOT NULL REFERENCES public.cars(id) ON DELETE CASCADE,
  distance_km NUMERIC(10, 2) NOT NULL CHECK (distance_km >= 0),
  started_at TIMESTAMPTZ NOT NULL,
  ended_at TIMESTAMPTZ NOT NULL,
  duration_seconds INTEGER NOT NULL CHECK (duration_seconds >= 0),
  start_odometer_km NUMERIC(10, 1),
  end_odometer_km NUMERIC(10, 1),
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_trip_logs_car_id ON public.trip_logs(car_id);
CREATE INDEX IF NOT EXISTS idx_trip_logs_user_id ON public.trip_logs(user_id);

ALTER TABLE public.trip_logs ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view their own trip logs"
  ON public.trip_logs FOR SELECT
  USING (auth.uid() = user_id);

CREATE POLICY "Users can insert their own trip logs"
  ON public.trip_logs FOR INSERT
  WITH CHECK (auth.uid() = user_id);
```

## Tipos de servicio (`service_type`)

| Valor | Descripción | Intervalo |
|---|---|---|
| `oil_change` | Cambio de aceite | 5.000 km / 6 meses |
| `tire_rotation` | Rotación de llantas | 10.000 km / 12 meses |
| `air_filter` | Filtro de aire | 15.000 km / 12 meses |
| `brake_check` | Revisión de frenos | 20.000 km / 12 meses |
| `tire_change` | Cambio de llantas | 40.000 km / 24 meses |
| `coolant` | Refrigerante | 40.000 km / 24 meses |
| `general_maintenance` | Mantenimiento general | 10.000 km / 6 meses |
