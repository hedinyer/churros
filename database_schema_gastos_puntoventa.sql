-- Tabla para gastos de punto de venta
CREATE TABLE IF NOT EXISTS public.gastos_puntoventa (
  id serial NOT NULL,
  sucursal_id integer NOT NULL,
  usuario_id bigint NOT NULL,
  tipo character varying(50) NOT NULL DEFAULT 'otro'::character varying,
  descripcion character varying(255) NOT NULL,
  monto numeric(10, 2) NOT NULL,
  categoria character varying(100) NULL,
  fecha date NOT NULL DEFAULT CURRENT_DATE,
  hora time without time zone NOT NULL DEFAULT CURRENT_TIME,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  updated_at timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT gastos_puntoventa_pkey PRIMARY KEY (id),
  CONSTRAINT gastos_puntoventa_sucursal_id_fkey FOREIGN KEY (sucursal_id) 
    REFERENCES sucursales (id) ON DELETE CASCADE,
  CONSTRAINT gastos_puntoventa_usuario_id_fkey FOREIGN KEY (usuario_id) 
    REFERENCES users (id) ON DELETE RESTRICT,
  CONSTRAINT gastos_puntoventa_monto_check CHECK (monto >= 0),
  CONSTRAINT gastos_puntoventa_tipo_check CHECK (
    (tipo)::text = ANY (
      ARRAY[
        'personal'::character varying,
        'pago_pedido'::character varying,
        'pago_ocasional'::character varying,
        'otro'::character varying
      ]::text[]
    )
  )
) TABLESPACE pg_default;

CREATE INDEX IF NOT EXISTS idx_gastos_puntoventa_sucursal 
  ON public.gastos_puntoventa USING btree (sucursal_id, fecha DESC, created_at DESC) 
  TABLESPACE pg_default;

CREATE INDEX IF NOT EXISTS idx_gastos_puntoventa_tipo 
  ON public.gastos_puntoventa USING btree (tipo) 
  TABLESPACE pg_default;

CREATE INDEX IF NOT EXISTS idx_gastos_puntoventa_fecha 
  ON public.gastos_puntoventa USING btree (fecha DESC) 
  TABLESPACE pg_default;

-- Trigger para actualizar updated_at
CREATE OR REPLACE FUNCTION update_gastos_puntoventa_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER update_gastos_puntoventa_updated_at
  BEFORE UPDATE ON public.gastos_puntoventa
  FOR EACH ROW
  EXECUTE FUNCTION update_gastos_puntoventa_updated_at();
