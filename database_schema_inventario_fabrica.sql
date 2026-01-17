-- ============================================
-- ESQUEMA DE BASE DE DATOS PARA INVENTARIO DE FÁBRICA
-- Sistema POS Churros - Control de Inventario de Fábrica
-- ============================================

-- Tabla de inventario de fábrica
CREATE TABLE IF NOT EXISTS public.inventario_fabrica (
    id SERIAL NOT NULL,
    producto_id INTEGER NOT NULL,
    cantidad INTEGER NOT NULL DEFAULT 0,
    ultima_actualizacion TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),

    CONSTRAINT inventario_fabrica_pkey PRIMARY KEY (id),
    CONSTRAINT inventario_fabrica_producto_id_key UNIQUE (producto_id),
    CONSTRAINT inventario_fabrica_producto_id_fkey FOREIGN KEY (producto_id)
        REFERENCES public.productos (id) ON DELETE CASCADE,
    CONSTRAINT inventario_fabrica_cantidad_check CHECK (cantidad >= 0)
) TABLESPACE pg_default;

-- Índice para optimizar consultas
CREATE INDEX IF NOT EXISTS idx_inventario_fabrica_producto
    ON public.inventario_fabrica USING btree (producto_id)
    TABLESPACE pg_default;

CREATE INDEX IF NOT EXISTS idx_inventario_fabrica_ultima_actualizacion
    ON public.inventario_fabrica USING btree (ultima_actualizacion DESC)
    TABLESPACE pg_default;

-- Trigger para actualizar updated_at
CREATE OR REPLACE FUNCTION update_inventario_fabrica_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER update_inventario_fabrica_updated_at
    BEFORE UPDATE ON public.inventario_fabrica
    FOR EACH ROW
    EXECUTE FUNCTION update_inventario_fabrica_updated_at();
