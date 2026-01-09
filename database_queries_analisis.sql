-- ============================================
-- QUERIES DE EJEMPLO PARA ANÁLISIS DE VENTAS
-- Sistema POS Churros
-- ============================================

-- 1. Ventas del día actual por sucursal
SELECT 
    s.nombre AS sucursal,
    COUNT(v.id) AS total_ventas,
    SUM(v.total) AS total_ingresos,
    AVG(v.total) AS promedio_venta,
    SUM(vd.cantidad) AS total_unidades
FROM public.ventas v
INNER JOIN public.sucursales s ON v.sucursal_id = s.id
LEFT JOIN public.venta_detalles vd ON v.id = vd.venta_id
WHERE v.fecha_venta = CURRENT_DATE
    AND v.estado = 'completada'
GROUP BY s.id, s.nombre
ORDER BY total_ingresos DESC;

-- 2. Ventas por rango de fechas
SELECT 
    fecha_venta,
    COUNT(id) AS total_ventas,
    SUM(total) AS total_ingresos,
    AVG(total) AS promedio_venta,
    MIN(total) AS venta_minima,
    MAX(total) AS venta_maxima
FROM public.ventas
WHERE fecha_venta BETWEEN '2024-01-01' AND '2024-12-31'
    AND estado = 'completada'
GROUP BY fecha_venta
ORDER BY fecha_venta DESC;

-- 3. Top 10 productos más vendidos en un período
SELECT 
    p.nombre AS producto,
    c.nombre AS categoria,
    SUM(vd.cantidad) AS unidades_vendidas,
    SUM(vd.precio_total) AS ingresos_totales,
    AVG(vd.precio_unitario) AS precio_promedio
FROM public.venta_detalles vd
INNER JOIN public.productos p ON vd.producto_id = p.id
LEFT JOIN public.categorias c ON p.categoria_id = c.id
INNER JOIN public.ventas v ON vd.venta_id = v.id
WHERE v.fecha_venta BETWEEN '2024-01-01' AND '2024-12-31'
    AND v.estado = 'completada'
GROUP BY p.id, p.nombre, c.nombre
ORDER BY unidades_vendidas DESC
LIMIT 10;

-- 4. Ventas por método de pago
SELECT 
    metodo_pago,
    COUNT(id) AS total_ventas,
    SUM(total) AS total_ingresos,
    ROUND(SUM(total) * 100.0 / (SELECT SUM(total) FROM public.ventas WHERE estado = 'completada'), 2) AS porcentaje
FROM public.ventas
WHERE estado = 'completada'
    AND fecha_venta >= CURRENT_DATE - INTERVAL '30 days'
GROUP BY metodo_pago
ORDER BY total_ingresos DESC;

-- 5. Ventas por hora del día (últimos 30 días)
SELECT 
    EXTRACT(HOUR FROM hora_venta) AS hora,
    COUNT(id) AS total_ventas,
    SUM(total) AS total_ingresos,
    AVG(total) AS promedio_venta
FROM public.ventas
WHERE fecha_venta >= CURRENT_DATE - INTERVAL '30 days'
    AND estado = 'completada'
GROUP BY EXTRACT(HOUR FROM hora_venta)
ORDER BY hora;

-- 6. Ventas por día de la semana
SELECT 
    TO_CHAR(fecha_venta, 'Day') AS dia_semana,
    EXTRACT(DOW FROM fecha_venta) AS dia_numero,
    COUNT(id) AS total_ventas,
    SUM(total) AS total_ingresos,
    AVG(total) AS promedio_venta
FROM public.ventas
WHERE fecha_venta >= CURRENT_DATE - INTERVAL '90 days'
    AND estado = 'completada'
GROUP BY TO_CHAR(fecha_venta, 'Day'), EXTRACT(DOW FROM fecha_venta)
ORDER BY dia_numero;

-- 7. Rendimiento de cajeros (último mes)
SELECT 
    u.user_id AS cajero,
    s.nombre AS sucursal,
    COUNT(v.id) AS total_ventas,
    SUM(v.total) AS total_ingresos,
    AVG(v.total) AS promedio_venta,
    COUNT(DISTINCT v.fecha_venta) AS dias_trabajados
FROM public.ventas v
INNER JOIN public.users u ON v.usuario_id = u.id
INNER JOIN public.sucursales s ON v.sucursal_id = s.id
WHERE v.fecha_venta >= CURRENT_DATE - INTERVAL '30 days'
    AND v.estado = 'completada'
GROUP BY u.id, u.user_id, s.id, s.nombre
ORDER BY total_ingresos DESC;

-- 8. Comparación mes actual vs mes anterior
SELECT 
    DATE_TRUNC('month', fecha_venta) AS mes,
    COUNT(id) AS total_ventas,
    SUM(total) AS total_ingresos,
    AVG(total) AS promedio_venta
FROM public.ventas
WHERE fecha_venta >= DATE_TRUNC('month', CURRENT_DATE - INTERVAL '2 months')
    AND estado = 'completada'
GROUP BY DATE_TRUNC('month', fecha_venta)
ORDER BY mes DESC;

-- 9. Productos con bajo stock (basado en ventas recientes vs inventario)
SELECT 
    p.id,
    p.nombre,
    c.nombre AS categoria,
    COALESCE(ia.cantidad, 0) AS stock_actual,
    SUM(vd.cantidad) AS unidades_vendidas_ultimos_7_dias,
    CASE 
        WHEN COALESCE(ia.cantidad, 0) = 0 THEN 'Sin stock'
        WHEN COALESCE(ia.cantidad, 0) < SUM(vd.cantidad) THEN 'Stock bajo'
        ELSE 'Stock normal'
    END AS estado_stock
FROM public.productos p
LEFT JOIN public.categorias c ON p.categoria_id = c.id
LEFT JOIN public.inventario_actual ia ON p.id = ia.producto_id
LEFT JOIN public.venta_detalles vd ON p.id = vd.producto_id
LEFT JOIN public.ventas v ON vd.venta_id = v.id
    AND v.fecha_venta >= CURRENT_DATE - INTERVAL '7 days'
    AND v.estado = 'completada'
WHERE p.activo = true
GROUP BY p.id, p.nombre, c.nombre, ia.cantidad
HAVING COALESCE(ia.cantidad, 0) < 10 OR SUM(vd.cantidad) > COALESCE(ia.cantidad, 0)
ORDER BY unidades_vendidas_ultimos_7_dias DESC NULLS LAST;

-- 10. Ventas pendientes de sincronización (offline)
SELECT 
    v.id,
    v.numero_ticket,
    s.nombre AS sucursal,
    u.user_id AS cajero,
    v.fecha_venta,
    v.hora_venta,
    v.total,
    v.created_at AS fecha_creacion
FROM public.ventas v
INNER JOIN public.sucursales s ON v.sucursal_id = s.id
INNER JOIN public.users u ON v.usuario_id = u.id
WHERE v.sincronizado = false
ORDER BY v.created_at ASC;

-- 11. Resumen de ventas por categoría
SELECT 
    c.nombre AS categoria,
    COUNT(DISTINCT vd.venta_id) AS ventas_con_categoria,
    SUM(vd.cantidad) AS unidades_vendidas,
    SUM(vd.precio_total) AS ingresos_totales,
    AVG(vd.precio_unitario) AS precio_promedio
FROM public.venta_detalles vd
INNER JOIN public.productos p ON vd.producto_id = p.id
INNER JOIN public.categorias c ON p.categoria_id = c.id
INNER JOIN public.ventas v ON vd.venta_id = v.id
WHERE v.fecha_venta >= CURRENT_DATE - INTERVAL '30 days'
    AND v.estado = 'completada'
GROUP BY c.id, c.nombre
ORDER BY ingresos_totales DESC;

-- 12. Ticket promedio por sucursal
SELECT 
    s.nombre AS sucursal,
    COUNT(v.id) AS total_ventas,
    SUM(v.total) AS total_ingresos,
    AVG(v.total) AS ticket_promedio,
    PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY v.total) AS ticket_mediano
FROM public.ventas v
INNER JOIN public.sucursales s ON v.sucursal_id = s.id
WHERE v.fecha_venta >= CURRENT_DATE - INTERVAL '30 days'
    AND v.estado = 'completada'
GROUP BY s.id, s.nombre
ORDER BY ticket_promedio DESC;

