-- Permitir tipo 'nomina' en gastos_varios
-- Ejecutar en Supabase SQL Editor

ALTER TABLE public.gastos_varios
  DROP CONSTRAINT IF EXISTS gastos_varios_tipo_check;

ALTER TABLE public.gastos_varios
  ADD CONSTRAINT gastos_varios_tipo_check CHECK (
    (tipo)::text = ANY (
      ARRAY[
        ('compra'::character varying)::text,
        ('pago'::character varying)::text,
        ('otro'::character varying)::text,
        ('nomina'::character varying)::text
      ]
    )
  );

