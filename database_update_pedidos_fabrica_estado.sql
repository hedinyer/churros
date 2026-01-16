-- Actualizar la restricción CHECK para incluir el estado 'en_preparacion'
-- Primero eliminar la restricción existente
ALTER TABLE public.pedidos_fabrica 
DROP CONSTRAINT IF EXISTS pedidos_fabrica_estado_check;

-- Agregar la nueva restricción con el estado 'en_preparacion'
ALTER TABLE public.pedidos_fabrica
ADD CONSTRAINT pedidos_fabrica_estado_check CHECK (
  (estado)::text = ANY (
    ARRAY[
      'pendiente'::character varying,
      'en_preparacion'::character varying,
      'enviado'::character varying,
      'entregado'::character varying,
      'cancelado'::character varying
    ]::text[]
  )
);
