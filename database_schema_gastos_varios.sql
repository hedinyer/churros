-- Tabla para gastos varios de la fábrica
CREATE TABLE IF NOT EXISTS public.gastos_varios (
  id serial NOT NULL,
  descripcion character varying(255) NOT NULL,
  monto numeric(10, 2) NOT NULL,
  tipo character varying(50) NOT NULL DEFAULT 'otro'::character varying,
  categoria character varying(100) NULL,
  fecha date NOT NULL DEFAULT CURRENT_DATE,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  updated_at timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT gastos_varios_pkey PRIMARY KEY (id),
  CONSTRAINT gastos_varios_monto_check CHECK (monto >= 0),
  CONSTRAINT gastos_varios_tipo_check CHECK (
    (tipo)::text = ANY (
      ARRAY[
        'compra'::character varying,
        'pago'::character varying,
        'otro'::character varying
      ]::text[]
    )
  )
) TABLESPACE pg_default;

CREATE INDEX IF NOT EXISTS idx_gastos_varios_fecha 
  ON public.gastos_varios USING btree (fecha DESC, created_at DESC) 
  TABLESPACE pg_default;

CREATE INDEX IF NOT EXISTS idx_gastos_varios_tipo 
  ON public.gastos_varios USING btree (tipo) 
  TABLESPACE pg_default;

-- Trigger para actualizar updated_at
CREATE OR REPLACE FUNCTION update_gastos_varios_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER update_gastos_varios_updated_at
  BEFORE UPDATE ON public.gastos_varios
  FOR EACH ROW
  EXECUTE FUNCTION update_gastos_varios_updated_at();
