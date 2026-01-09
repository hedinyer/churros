-- ============================================
-- ESQUEMA DE BASE DE DATOS PARA VENTAS
-- Sistema POS Churros - Análisis de Ventas
-- ============================================

-- Tabla principal de ventas
CREATE TABLE IF NOT EXISTS public.ventas (
    id SERIAL NOT NULL,
    sucursal_id INTEGER NOT NULL,
    usuario_id BIGINT NOT NULL,
    fecha_venta DATE NOT NULL DEFAULT CURRENT_DATE,
    hora_venta TIME WITHOUT TIME ZONE NOT NULL DEFAULT CURRENT_TIME,
    total DECIMAL(10, 2) NOT NULL DEFAULT 0.00,
    subtotal DECIMAL(10, 2) NOT NULL DEFAULT 0.00,
    descuento DECIMAL(10, 2) NOT NULL DEFAULT 0.00,
    impuesto DECIMAL(10, 2) NOT NULL DEFAULT 0.00,
    metodo_pago VARCHAR(50) NULL DEFAULT 'efectivo',
    estado VARCHAR(20) NOT NULL DEFAULT 'completada',
    numero_ticket VARCHAR(50) NULL,
    observaciones TEXT NULL,
    sincronizado BOOLEAN NOT NULL DEFAULT true,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    
    CONSTRAINT ventas_pkey PRIMARY KEY (id),
    CONSTRAINT ventas_sucursal_id_fkey FOREIGN KEY (sucursal_id) 
        REFERENCES public.sucursales (id) ON DELETE CASCADE,
    CONSTRAINT ventas_usuario_id_fkey FOREIGN KEY (usuario_id) 
        REFERENCES public.users (id) ON DELETE RESTRICT,
    CONSTRAINT ventas_estado_check CHECK (
        estado IN ('completada', 'cancelada', 'pendiente', 'reembolsada')
    ),
    CONSTRAINT ventas_metodo_pago_check CHECK (
        metodo_pago IN ('efectivo', 'tarjeta', 'transferencia', 'mixto')
    ),
    CONSTRAINT ventas_total_check CHECK (total >= 0),
    CONSTRAINT ventas_subtotal_check CHECK (subtotal >= 0),
    CONSTRAINT ventas_descuento_check CHECK (descuento >= 0),
    CONSTRAINT ventas_impuesto_check CHECK (impuesto >= 0)
) TABLESPACE pg_default;

-- Tabla de detalles de venta (productos vendidos)
CREATE TABLE IF NOT EXISTS public.venta_detalles (
    id SERIAL NOT NULL,
    venta_id INTEGER NOT NULL,
    producto_id INTEGER NOT NULL,
    cantidad INTEGER NOT NULL DEFAULT 1,
    precio_unitario DECIMAL(10, 2) NOT NULL,
    precio_total DECIMAL(10, 2) NOT NULL,
    descuento DECIMAL(10, 2) NOT NULL DEFAULT 0.00,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    
    CONSTRAINT venta_detalles_pkey PRIMARY KEY (id),
    CONSTRAINT venta_detalles_venta_id_fkey FOREIGN KEY (venta_id) 
        REFERENCES public.ventas (id) ON DELETE CASCADE,
    CONSTRAINT venta_detalles_producto_id_fkey FOREIGN KEY (producto_id) 
        REFERENCES public.productos (id) ON DELETE RESTRICT,
    CONSTRAINT venta_detalles_cantidad_check CHECK (cantidad > 0),
    CONSTRAINT venta_detalles_precio_unitario_check CHECK (precio_unitario >= 0),
    CONSTRAINT venta_detalles_precio_total_check CHECK (precio_total >= 0),
    CONSTRAINT venta_detalles_descuento_check CHECK (descuento >= 0)
) TABLESPACE pg_default;

-- Índices para optimizar consultas de análisis
CREATE INDEX IF NOT EXISTS idx_ventas_sucursal_fecha 
    ON public.ventas USING btree (sucursal_id, fecha_venta DESC) 
    TABLESPACE pg_default;

CREATE INDEX IF NOT EXISTS idx_ventas_fecha_hora 
    ON public.ventas USING btree (fecha_venta DESC, hora_venta DESC) 
    TABLESPACE pg_default;

CREATE INDEX IF NOT EXISTS idx_ventas_usuario 
    ON public.ventas USING btree (usuario_id, fecha_venta DESC) 
    TABLESPACE pg_default;

CREATE INDEX IF NOT EXISTS idx_ventas_estado 
    ON public.ventas USING btree (estado, fecha_venta DESC) 
    TABLESPACE pg_default;

CREATE INDEX IF NOT EXISTS idx_ventas_metodo_pago 
    ON public.ventas USING btree (metodo_pago, fecha_venta DESC) 
    TABLESPACE pg_default;

CREATE INDEX IF NOT EXISTS idx_ventas_sincronizado 
    ON public.ventas USING btree (sincronizado) 
    WHERE sincronizado = false
    TABLESPACE pg_default;

CREATE INDEX IF NOT EXISTS idx_venta_detalles_venta_id 
    ON public.venta_detalles USING btree (venta_id) 
    TABLESPACE pg_default;

CREATE INDEX IF NOT EXISTS idx_venta_detalles_producto_id 
    ON public.venta_detalles USING btree (producto_id, created_at DESC) 
    TABLESPACE pg_default;

-- Función para actualizar updated_at automáticamente
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger para actualizar updated_at en ventas
CREATE TRIGGER update_ventas_updated_at
    BEFORE UPDATE ON public.ventas
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- Vista para análisis de ventas diarias por sucursal
CREATE OR REPLACE VIEW public.vista_ventas_diarias AS
SELECT 
    v.sucursal_id,
    s.nombre AS sucursal_nombre,
    v.fecha_venta,
    COUNT(v.id) AS total_ventas,
    SUM(v.total) AS total_ingresos,
    SUM(v.subtotal) AS total_subtotal,
    SUM(v.descuento) AS total_descuentos,
    SUM(v.impuesto) AS total_impuestos,
    AVG(v.total) AS promedio_venta,
    MIN(v.total) AS venta_minima,
    MAX(v.total) AS venta_maxima,
    COUNT(DISTINCT v.usuario_id) AS total_cajeros,
    COUNT(DISTINCT vd.producto_id) AS productos_vendidos,
    SUM(vd.cantidad) AS total_unidades_vendidas
FROM public.ventas v
INNER JOIN public.sucursales s ON v.sucursal_id = s.id
LEFT JOIN public.venta_detalles vd ON v.id = vd.venta_id
WHERE v.estado = 'completada'
GROUP BY v.sucursal_id, s.nombre, v.fecha_venta
ORDER BY v.fecha_venta DESC, v.sucursal_id;

-- Vista para análisis de productos más vendidos
CREATE OR REPLACE VIEW public.vista_productos_mas_vendidos AS
SELECT 
    p.id AS producto_id,
    p.nombre AS producto_nombre,
    c.nombre AS categoria_nombre,
    COUNT(vd.id) AS veces_vendido,
    SUM(vd.cantidad) AS total_unidades_vendidas,
    SUM(vd.precio_total) AS total_ingresos_producto,
    AVG(vd.precio_unitario) AS precio_promedio,
    MIN(vd.precio_unitario) AS precio_minimo,
    MAX(vd.precio_unitario) AS precio_maximo,
    SUM(vd.cantidad * vd.precio_unitario) AS valor_total_vendido
FROM public.venta_detalles vd
INNER JOIN public.productos p ON vd.producto_id = p.id
LEFT JOIN public.categorias c ON p.categoria_id = c.id
INNER JOIN public.ventas v ON vd.venta_id = v.id
WHERE v.estado = 'completada'
GROUP BY p.id, p.nombre, c.nombre
ORDER BY total_unidades_vendidas DESC;

-- Vista para análisis de ventas por hora del día
CREATE OR REPLACE VIEW public.vista_ventas_por_hora AS
SELECT 
    EXTRACT(HOUR FROM v.hora_venta) AS hora_del_dia,
    COUNT(v.id) AS total_ventas,
    SUM(v.total) AS total_ingresos,
    AVG(v.total) AS promedio_venta,
    SUM(vd.cantidad) AS total_unidades_vendidas
FROM public.ventas v
LEFT JOIN public.venta_detalles vd ON v.id = vd.venta_id
WHERE v.estado = 'completada'
GROUP BY EXTRACT(HOUR FROM v.hora_venta)
ORDER BY hora_del_dia;

-- Vista para análisis de rendimiento de cajeros
CREATE OR REPLACE VIEW public.vista_rendimiento_cajeros AS
SELECT 
    u.id AS usuario_id,
    u.user_id AS usuario_nombre,
    v.sucursal_id,
    s.nombre AS sucursal_nombre,
    COUNT(v.id) AS total_ventas,
    SUM(v.total) AS total_ingresos,
    AVG(v.total) AS promedio_venta,
    MIN(v.fecha_venta) AS primera_venta,
    MAX(v.fecha_venta) AS ultima_venta,
    COUNT(DISTINCT v.fecha_venta) AS dias_trabajados
FROM public.ventas v
INNER JOIN public.users u ON v.usuario_id = u.id
INNER JOIN public.sucursales s ON v.sucursal_id = s.id
WHERE v.estado = 'completada'
GROUP BY u.id, u.user_id, v.sucursal_id, s.nombre
ORDER BY total_ingresos DESC;

-- Comentarios para documentación
COMMENT ON TABLE public.ventas IS 'Tabla principal de ventas/transacciones del sistema POS';
COMMENT ON TABLE public.venta_detalles IS 'Detalles de productos vendidos en cada venta';
COMMENT ON COLUMN public.ventas.numero_ticket IS 'Número de ticket o factura de la venta';
COMMENT ON COLUMN public.ventas.sincronizado IS 'Indica si la venta fue sincronizada desde dispositivo offline';
COMMENT ON COLUMN public.ventas.metodo_pago IS 'Método de pago utilizado: efectivo, tarjeta, transferencia, mixto';
COMMENT ON COLUMN public.ventas.estado IS 'Estado de la venta: completada, cancelada, pendiente, reembolsada';

