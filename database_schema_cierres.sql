-- ============================================
-- ESQUEMA DE BASE DE DATOS PARA CIERRES
-- Sistema POS Churros - Gestión de Cierres de Día
-- ============================================

-- Tabla principal de cierres del día
CREATE TABLE IF NOT EXISTS public.cierres_dia (
    id SERIAL NOT NULL,
    sucursal_id INTEGER NOT NULL,
    apertura_id INTEGER NOT NULL,
    usuario_cierre BIGINT NOT NULL,
    fecha_cierre DATE NOT NULL DEFAULT CURRENT_DATE,
    hora_cierre TIME WITHOUT TIME ZONE NOT NULL DEFAULT CURRENT_TIME,
    total_productos INTEGER NOT NULL DEFAULT 0,
    total_desperdicio INTEGER NOT NULL DEFAULT 0,
    total_ventas DECIMAL(10, 2) NOT NULL DEFAULT 0.00,
    estado VARCHAR(20) NOT NULL DEFAULT 'completado',
    observaciones TEXT NULL,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),

    CONSTRAINT cierres_dia_pkey PRIMARY KEY (id),
    CONSTRAINT cierres_dia_sucursal_id_fkey FOREIGN KEY (sucursal_id)
        REFERENCES public.sucursales (id) ON DELETE CASCADE,
    CONSTRAINT cierres_dia_apertura_id_fkey FOREIGN KEY (apertura_id)
        REFERENCES public.aperturas_dia (id) ON DELETE CASCADE,
    CONSTRAINT cierres_dia_usuario_cierre_fkey FOREIGN KEY (usuario_cierre)
        REFERENCES public.users (id) ON DELETE RESTRICT,
    CONSTRAINT cierres_dia_estado_check CHECK (
        estado IN ('completado', 'pendiente', 'cancelado')
    ),
    CONSTRAINT cierres_dia_total_productos_check CHECK (total_productos >= 0),
    CONSTRAINT cierres_dia_total_desperdicio_check CHECK (total_desperdicio >= 0),
    CONSTRAINT cierres_dia_total_ventas_check CHECK (total_ventas >= 0)
) TABLESPACE pg_default;

-- Tabla de inventario de cierre (productos al cerrar el día)
CREATE TABLE IF NOT EXISTS public.inventario_cierre (
    id SERIAL NOT NULL,
    cierre_id INTEGER NOT NULL,
    producto_id INTEGER NOT NULL,
    cantidad_final INTEGER NOT NULL DEFAULT 0,
    cantidad_sobrantes INTEGER NOT NULL DEFAULT 0,
    cantidad_vencido INTEGER NOT NULL DEFAULT 0,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),

    CONSTRAINT inventario_cierre_pkey PRIMARY KEY (id),
    CONSTRAINT inventario_cierre_cierre_id_producto_id_key UNIQUE (cierre_id, producto_id),
    CONSTRAINT inventario_cierre_cierre_id_fkey FOREIGN KEY (cierre_id)
        REFERENCES public.cierres_dia (id) ON DELETE CASCADE,
    CONSTRAINT inventario_cierre_producto_id_fkey FOREIGN KEY (producto_id)
        REFERENCES public.productos (id) ON DELETE CASCADE,
    CONSTRAINT inventario_cierre_cantidad_final_check CHECK (cantidad_final >= 0),
    CONSTRAINT inventario_cierre_cantidad_sobrantes_check CHECK (cantidad_sobrantes >= 0),
    CONSTRAINT inventario_cierre_cantidad_vencido_check CHECK (cantidad_vencido >= 0)
) TABLESPACE pg_default;

-- Índices para optimizar consultas
CREATE INDEX IF NOT EXISTS idx_cierres_dia_sucursal_fecha
    ON public.cierres_dia USING btree (sucursal_id, fecha_cierre DESC)
    TABLESPACE pg_default;

CREATE INDEX IF NOT EXISTS idx_cierres_dia_apertura_id
    ON public.cierres_dia USING btree (apertura_id)
    TABLESPACE pg_default;

CREATE INDEX IF NOT EXISTS idx_cierres_dia_fecha_hora
    ON public.cierres_dia USING btree (fecha_cierre DESC, hora_cierre DESC)
    TABLESPACE pg_default;

CREATE INDEX IF NOT EXISTS idx_cierres_dia_usuario
    ON public.cierres_dia USING btree (usuario_cierre, fecha_cierre DESC)
    TABLESPACE pg_default;

CREATE INDEX IF NOT EXISTS idx_cierres_dia_estado
    ON public.cierres_dia USING btree (estado, fecha_cierre DESC)
    TABLESPACE pg_default;

CREATE INDEX IF NOT EXISTS idx_inventario_cierre
    ON public.inventario_cierre USING btree (cierre_id, producto_id)
    TABLESPACE pg_default;

-- Trigger para actualizar updated_at en cierres_dia
CREATE TRIGGER update_cierres_dia_updated_at
    BEFORE UPDATE ON public.cierres_dia
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- Vista para análisis de cierres por sucursal y fecha
CREATE OR REPLACE VIEW public.vista_cierres_diarios AS
SELECT
    c.sucursal_id,
    s.nombre AS sucursal_nombre,
    c.fecha_cierre,
    COUNT(c.id) AS total_cierres,
    SUM(c.total_productos) AS total_productos_cerrados,
    SUM(c.total_desperdicio) AS total_desperdicio,
    SUM(c.total_ventas) AS total_ventas_cierre,
    COUNT(DISTINCT ic.producto_id) AS productos_distintos,
    COUNT(DISTINCT c.usuario_cierre) AS usuarios_que_cerraron
FROM public.cierres_dia c
INNER JOIN public.sucursales s ON c.sucursal_id = s.id
LEFT JOIN public.inventario_cierre ic ON c.id = ic.cierre_id
WHERE c.estado = 'completado'
GROUP BY c.sucursal_id, s.nombre, c.fecha_cierre
ORDER BY c.fecha_cierre DESC, c.sucursal_id;

-- Comentarios para documentación
COMMENT ON TABLE public.cierres_dia IS 'Tabla principal de cierres del día';
COMMENT ON TABLE public.inventario_cierre IS 'Inventario de productos al momento del cierre del día';
COMMENT ON COLUMN public.cierres_dia.apertura_id IS 'Referencia a la apertura del día que se está cerrando';
COMMENT ON COLUMN public.cierres_dia.total_productos IS 'Número total de productos diferentes en el cierre';
COMMENT ON COLUMN public.cierres_dia.total_desperdicio IS 'Total de unidades desperdiciadas (vencidas/mal estado)';
COMMENT ON COLUMN public.cierres_dia.estado IS 'Estado del cierre: completado, pendiente, cancelado';
COMMENT ON COLUMN public.inventario_cierre.cantidad_final IS 'Stock final al momento del cierre';
COMMENT ON COLUMN public.inventario_cierre.cantidad_sobrantes IS 'Cantidad de sobrantes';
COMMENT ON COLUMN public.inventario_cierre.cantidad_vencido IS 'Cantidad vencida o en mal estado';

