-- ============================================
-- RPC ATÓMICA: RECARGAR FRITOS Y DESCONTAR CRUDOS
-- Evita inconsistencias (frito +, crudo sin -) en escenarios de:
-- - mala conexión
-- - concurrencia (2 celulares recargando al mismo tiempo)
--
-- Instalar en Supabase: SQL Editor -> pegar y ejecutar.
-- Requiere tablas:
-- - recargas_inventario, recarga_detalles, inventario_actual
-- ============================================

CREATE OR REPLACE FUNCTION public.guardar_recarga_inventario_y_descontar_crudos(
  p_sucursal_id INTEGER,
  p_usuario_id BIGINT,
  p_observaciones TEXT,
  -- JSONB array: [{ "producto_id": 9, "cantidad": 5 }, ...] (estos son los productos que se RECARGAN, típicamente FRITOS)
  p_productos_recarga JSONB,
  -- JSONB array: [{ "producto_id": 8, "cantidad": 5 }, ...] (estos son los productos CRUDOS que se DESCUENTAN)
  p_crudos_a_descontar JSONB
) RETURNS INTEGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_recarga_id INTEGER;
  v_now TIMESTAMPTZ := NOW();
  v_fecha DATE := CURRENT_DATE;
  v_hora TIME := LOCALTIME;

  v_item JSONB;
  v_producto_id INTEGER;
  v_cantidad INTEGER;

  v_prev INTEGER;
  v_final INTEGER;
BEGIN
  IF p_sucursal_id IS NULL OR p_usuario_id IS NULL THEN
    RAISE EXCEPTION 'Parámetros requeridos faltantes';
  END IF;

  IF p_productos_recarga IS NULL OR jsonb_typeof(p_productos_recarga) <> 'array' OR jsonb_array_length(p_productos_recarga) = 0 THEN
    RAISE EXCEPTION 'p_productos_recarga debe ser un array JSONB no vacío';
  END IF;

  -- 1) Validar crudOs (si se envía) que existan y tengan stock suficiente
  IF p_crudos_a_descontar IS NOT NULL AND jsonb_typeof(p_crudos_a_descontar) = 'array' AND jsonb_array_length(p_crudos_a_descontar) > 0 THEN
    FOR v_item IN SELECT * FROM jsonb_array_elements(p_crudos_a_descontar)
    LOOP
      v_producto_id := (v_item->>'producto_id')::INTEGER;
      v_cantidad := (v_item->>'cantidad')::INTEGER;

      IF v_producto_id IS NULL OR v_cantidad IS NULL OR v_cantidad <= 0 THEN
        RAISE EXCEPTION 'Item inválido en p_crudos_a_descontar: %', v_item;
      END IF;

      SELECT ia.cantidad
        INTO v_prev
      FROM public.inventario_actual ia
      WHERE ia.sucursal_id = p_sucursal_id
        AND ia.producto_id = v_producto_id
      FOR UPDATE;

      IF v_prev IS NULL THEN
        RAISE EXCEPTION 'No existe inventario_actual para producto crudo % en sucursal %', v_producto_id, p_sucursal_id;
      END IF;

      IF v_prev < v_cantidad THEN
        RAISE EXCEPTION 'Inventario insuficiente (crudo %). Disponible: %, Solicitado: %', v_producto_id, v_prev, v_cantidad;
      END IF;
    END LOOP;
  END IF;

  -- 2) Insertar cabecera de recarga
  INSERT INTO public.recargas_inventario (
    sucursal_id,
    usuario_id,
    fecha_recarga,
    hora_recarga,
    total_productos,
    estado,
    observaciones,
    sincronizado,
    created_at,
    updated_at
  ) VALUES (
    p_sucursal_id,
    p_usuario_id,
    v_fecha,
    v_hora,
    jsonb_array_length(p_productos_recarga),
    'completada',
    p_observaciones,
    TRUE,
    v_now,
    v_now
  )
  RETURNING id INTO v_recarga_id;

  -- 3) Aplicar recarga (+) y guardar detalles (con cantidades anterior/final)
  FOR v_item IN SELECT * FROM jsonb_array_elements(p_productos_recarga)
  LOOP
    v_producto_id := (v_item->>'producto_id')::INTEGER;
    v_cantidad := (v_item->>'cantidad')::INTEGER;

    IF v_producto_id IS NULL OR v_cantidad IS NULL OR v_cantidad <= 0 THEN
      RAISE EXCEPTION 'Item inválido en p_productos_recarga: %', v_item;
    END IF;

    -- Leer cantidad anterior con lock (si existe)
    SELECT ia.cantidad
      INTO v_prev
    FROM public.inventario_actual ia
    WHERE ia.sucursal_id = p_sucursal_id
      AND ia.producto_id = v_producto_id
    FOR UPDATE;

    v_prev := COALESCE(v_prev, 0);
    v_final := v_prev + v_cantidad;

    -- Upsert atómico: suma a la cantidad existente
    INSERT INTO public.inventario_actual (
      sucursal_id,
      producto_id,
      cantidad,
      ultima_actualizacion
    ) VALUES (
      p_sucursal_id,
      v_producto_id,
      v_cantidad,
      v_now
    )
    ON CONFLICT (sucursal_id, producto_id)
    DO UPDATE SET
      cantidad = public.inventario_actual.cantidad + EXCLUDED.cantidad,
      ultima_actualizacion = EXCLUDED.ultima_actualizacion;

    INSERT INTO public.recarga_detalles (
      recarga_id,
      producto_id,
      cantidad_anterior,
      cantidad_recargada,
      cantidad_final,
      precio_unitario,
      costo_total,
      created_at
    ) VALUES (
      v_recarga_id,
      v_producto_id,
      v_prev,
      v_cantidad,
      v_final,
      NULL,
      NULL,
      v_now
    );
  END LOOP;

  -- 4) Aplicar descuentos a crudos (-)
  IF p_crudos_a_descontar IS NOT NULL AND jsonb_typeof(p_crudos_a_descontar) = 'array' AND jsonb_array_length(p_crudos_a_descontar) > 0 THEN
    FOR v_item IN SELECT * FROM jsonb_array_elements(p_crudos_a_descontar)
    LOOP
      v_producto_id := (v_item->>'producto_id')::INTEGER;
      v_cantidad := (v_item->>'cantidad')::INTEGER;

      UPDATE public.inventario_actual ia
      SET
        cantidad = ia.cantidad - v_cantidad,
        ultima_actualizacion = v_now
      WHERE ia.sucursal_id = p_sucursal_id
        AND ia.producto_id = v_producto_id
        AND ia.cantidad >= v_cantidad;

      IF NOT FOUND THEN
        RAISE EXCEPTION 'No se pudo descontar crudo % (posible carrera o inventario insuficiente).', v_producto_id;
      END IF;
    END LOOP;
  END IF;

  RETURN v_recarga_id;
END;
$$;

