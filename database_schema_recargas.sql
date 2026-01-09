-- ============================================
-- ESQUEMA DE BASE DE DATOS PARA RECARGAS
-- Sistema POS Churros - Gestión de Recargas de Inventario
-- ============================================

-- Tabla principal de recargas de productos
CREATE TABLE IF NOT EXISTS public.recargas_inventario (
    id SERIAL NOT NULL,
    sucursal_id INTEGER NOT NULL,
    usuario_id BIGINT NOT NULL,
    fecha_recarga DATE NOT NULL DEFAULT CURRENT_DATE,
    hora_recarga TIME WITHOUT TIME ZONE NOT NULL DEFAULT CURRENT_TIME,
    total_productos INTEGER NOT NULL DEFAULT 0,
    estado VARCHAR(20) NOT NULL DEFAULT 'completada',
    observaciones TEXT NULL,
    sincronizado BOOLEAN NOT NULL DEFAULT true,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),

    CONSTRAINT recargas_inventario_pkey PRIMARY KEY (id),
    CONSTRAINT recargas_inventario_sucursal_id_fkey FOREIGN KEY (sucursal_id)
        REFERENCES public.sucursales (id) ON DELETE CASCADE,
    CONSTRAINT recargas_inventario_usuario_id_fkey FOREIGN KEY (usuario_id)
        REFERENCES public.users (id) ON DELETE RESTRICT,
    CONSTRAINT recargas_inventario_estado_check CHECK (
        estado IN ('completada', 'pendiente', 'cancelada')
    ),
    CONSTRAINT recargas_inventario_total_productos_check CHECK (total_productos >= 0)
) TABLESPACE pg_default;

-- Tabla de detalles de recarga (productos recargados)
CREATE TABLE IF NOT EXISTS public.recarga_detalles (
    id SERIAL NOT NULL,
    recarga_id INTEGER NOT NULL,
    producto_id INTEGER NOT NULL,
    cantidad_anterior INTEGER NOT NULL DEFAULT 0,
    cantidad_recargada INTEGER NOT NULL,
    cantidad_final INTEGER NOT NULL,
    precio_unitario DECIMAL(10, 2) NULL, -- precio de compra del producto
    costo_total DECIMAL(10, 2) NULL, -- costo total de la recarga
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),

    CONSTRAINT recarga_detalles_pkey PRIMARY KEY (id),
    CONSTRAINT recarga_detalles_recarga_id_fkey FOREIGN KEY (recarga_id)
        REFERENCES public.recargas_inventario (id) ON DELETE CASCADE,
    CONSTRAINT recarga_detalles_producto_id_fkey FOREIGN KEY (producto_id)
        REFERENCES public.productos (id) ON DELETE RESTRICT,
    CONSTRAINT recarga_detalles_cantidad_anterior_check CHECK (cantidad_anterior >= 0),
    CONSTRAINT recarga_detalles_cantidad_recargada_check CHECK (cantidad_recargada > 0),
    CONSTRAINT recarga_detalles_cantidad_final_check CHECK (cantidad_final >= 0),
    CONSTRAINT recarga_detalles_precio_unitario_check CHECK (precio_unitario >= 0),
    CONSTRAINT recarga_detalles_costo_total_check CHECK (costo_total >= 0)
) TABLESPACE pg_default;

-- Índices para optimizar consultas
CREATE INDEX IF NOT EXISTS idx_recargas_inventario_sucursal_fecha
    ON public.recargas_inventario USING btree (sucursal_id, fecha_recarga DESC)
    TABLESPACE pg_default;

CREATE INDEX IF NOT EXISTS idx_recargas_inventario_fecha_hora
    ON public.recargas_inventario USING btree (fecha_recarga DESC, hora_recarga DESC)
    TABLESPACE pg_default;

CREATE INDEX IF NOT EXISTS idx_recargas_inventario_usuario
    ON public.recargas_inventario USING btree (usuario_id, fecha_recarga DESC)
    TABLESPACE pg_default;

CREATE INDEX IF NOT EXISTS idx_recargas_inventario_estado
    ON public.recargas_inventario USING btree (estado, fecha_recarga DESC)
    TABLESPACE pg_default;

CREATE INDEX IF NOT EXISTS idx_recargas_inventario_sincronizado
    ON public.recargas_inventario USING btree (sincronizado)
    WHERE sincronizado = false
    TABLESPACE pg_default;

CREATE INDEX IF NOT EXISTS idx_recarga_detalles_recarga_id
    ON public.recarga_detalles USING btree (recarga_id)
    TABLESPACE pg_default;

CREATE INDEX IF NOT EXISTS idx_recarga_detalles_producto_id
    ON public.recarga_detalles USING btree (producto_id, created_at DESC)
    TABLESPACE pg_default;

-- Trigger para actualizar updated_at en recargas_inventario
CREATE TRIGGER update_recargas_inventario_updated_at
    BEFORE UPDATE ON public.recargas_inventario
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- Vista para análisis de recargas por sucursal y fecha
CREATE OR REPLACE VIEW public.vista_recargas_diarias AS
SELECT
    r.sucursal_id,
    s.nombre AS sucursal_nombre,
    r.fecha_recarga,
    COUNT(r.id) AS total_recargas,
    SUM(r.total_productos) AS total_productos_recargados,
    COUNT(DISTINCT rd.producto_id) AS productos_distintos,
    SUM(rd.cantidad_recargada) AS total_unidades_recargadas,
    SUM(rd.costo_total) AS costo_total_recargas,
    COUNT(DISTINCT r.usuario_id) AS usuarios_que_recargaron
FROM public.recargas_inventario r
INNER JOIN public.sucursales s ON r.sucursal_id = s.id
LEFT JOIN public.recarga_detalles rd ON r.id = rd.recarga_id
WHERE r.estado = 'completada'
GROUP BY r.sucursal_id, s.nombre, r.fecha_recarga
ORDER BY r.fecha_recarga DESC, r.sucursal_id;

-- Vista para productos más recargados
CREATE OR REPLACE VIEW public.vista_productos_mas_recargados AS
SELECT
    p.id AS producto_id,
    p.nombre AS producto_nombre,
    c.nombre AS categoria_nombre,
    COUNT(rd.id) AS veces_recargado,
    SUM(rd.cantidad_recargada) AS total_unidades_recargadas,
    AVG(rd.precio_unitario) AS precio_promedio_compra,
    MIN(rd.precio_unitario) AS precio_minimo_compra,
    MAX(rd.precio_unitario) AS precio_maximo_compra,
    SUM(rd.costo_total) AS costo_total_compras
FROM public.recarga_detalles rd
INNER JOIN public.productos p ON rd.producto_id = p.id
LEFT JOIN public.categorias c ON p.categoria_id = c.id
INNER JOIN public.recargas_inventario r ON rd.recarga_id = r.id
WHERE r.estado = 'completada'
GROUP BY p.id, p.nombre, c.nombre
ORDER BY total_unidades_recargadas DESC;

-- Comentarios para documentación
COMMENT ON TABLE public.recargas_inventario IS 'Tabla principal de recargas de inventario';
COMMENT ON TABLE public.recarga_detalles IS 'Detalles de productos recargados en cada recarga';
COMMENT ON COLUMN public.recargas_inventario.total_productos IS 'Número total de productos diferentes recargados';
COMMENT ON COLUMN public.recargas_inventario.sincronizado IS 'Indica si la recarga fue sincronizada desde dispositivo offline';
COMMENT ON COLUMN public.recargas_inventario.estado IS 'Estado de la recarga: completada, pendiente, cancelada';
COMMENT ON COLUMN public.recarga_detalles.cantidad_anterior IS 'Stock disponible antes de la recarga';
COMMENT ON COLUMN public.recarga_detalles.cantidad_final IS 'Stock disponible después de la recarga (anterior + recargada)';
