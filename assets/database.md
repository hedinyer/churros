create table public.aperturas_dia (
  id serial not null,
  sucursal_id integer not null,
  fecha_apertura date not null default CURRENT_DATE,
  hora_apertura time without time zone not null default CURRENT_TIME,
  usuario_apertura bigint null,
  estado character varying(20) not null default 'abierta'::character varying,
  total_articulos integer not null default 0,
  created_at timestamp with time zone null default now(),
  constraint aperturas_dia_pkey primary key (id),
  constraint aperturas_dia_sucursal_id_fecha_apertura_key unique (sucursal_id, fecha_apertura),
  constraint aperturas_dia_sucursal_id_fkey foreign KEY (sucursal_id) references sucursales (id) on delete CASCADE,
  constraint aperturas_dia_usuario_apertura_fkey foreign KEY (usuario_apertura) references users (id),
  constraint aperturas_dia_estado_check check (
    (
      (estado)::text = any (
        (
          array[
            'abierta'::character varying,
            'cerrada'::character varying,
            'cancelada'::character varying
          ]
        )::text[]
      )
    )
  )
) TABLESPACE pg_default;

create index IF not exists idx_aperturas_sucursal_fecha on public.aperturas_dia using btree (sucursal_id, fecha_apertura) TABLESPACE pg_default;


create table public.categorias (
  id serial not null,
  nombre character varying(50) not null,
  descripcion character varying(255) null,
  icono character varying(50) null,
  constraint categorias_pkey primary key (id),
  constraint categorias_nombre_key unique (nombre)
) TABLESPACE pg_default;


create table public.cierres_dia (
  id serial not null,
  sucursal_id integer not null,
  apertura_id integer not null,
  usuario_cierre bigint not null,
  fecha_cierre date not null default CURRENT_DATE,
  hora_cierre time without time zone not null default CURRENT_TIME,
  total_productos integer not null default 0,
  total_desperdicio integer not null default 0,
  total_ventas numeric(10, 2) not null default 0.00,
  estado character varying(20) not null default 'completado'::character varying,
  observaciones text null,
  created_at timestamp with time zone not null default now(),
  updated_at timestamp with time zone not null default now(),
  constraint cierres_dia_pkey primary key (id),
  constraint cierres_dia_apertura_id_fkey foreign KEY (apertura_id) references aperturas_dia (id) on delete CASCADE,
  constraint cierres_dia_sucursal_id_fkey foreign KEY (sucursal_id) references sucursales (id) on delete CASCADE,
  constraint cierres_dia_usuario_cierre_fkey foreign KEY (usuario_cierre) references users (id) on delete RESTRICT,
  constraint cierres_dia_total_desperdicio_check check ((total_desperdicio >= 0)),
  constraint cierres_dia_total_productos_check check ((total_productos >= 0)),
  constraint cierres_dia_estado_check check (
    (
      (estado)::text = any (
        (
          array[
            'completado'::character varying,
            'pendiente'::character varying,
            'cancelado'::character varying
          ]
        )::text[]
      )
    )
  ),
  constraint cierres_dia_total_ventas_check check ((total_ventas >= (0)::numeric))
) TABLESPACE pg_default;

create trigger update_cierres_dia_updated_at BEFORE
update on cierres_dia for EACH row
execute FUNCTION update_updated_at_column ();

create table public.inventario_actual (
  id serial not null,
  sucursal_id integer not null,
  producto_id integer not null,
  cantidad integer not null default 0,
  ultima_actualizacion timestamp with time zone null default now(),
  constraint inventario_actual_pkey primary key (id),
  constraint inventario_actual_sucursal_id_producto_id_key unique (sucursal_id, producto_id),
  constraint inventario_actual_producto_id_fkey foreign KEY (producto_id) references productos (id) on delete CASCADE,
  constraint inventario_actual_sucursal_id_fkey foreign KEY (sucursal_id) references sucursales (id) on delete CASCADE,
  constraint inventario_actual_cantidad_check check ((cantidad >= 0))
) TABLESPACE pg_default;

create index IF not exists idx_inventario_actual on public.inventario_actual using btree (sucursal_id, producto_id) TABLESPACE pg_default;


create table public.inventario_apertura (
  id serial not null,
  apertura_id integer not null,
  producto_id integer not null,
  cantidad_inicial integer not null default 0,
  created_at timestamp with time zone null default now(),
  constraint inventario_apertura_pkey primary key (id),
  constraint inventario_apertura_apertura_id_producto_id_key unique (apertura_id, producto_id),
  constraint inventario_apertura_apertura_id_fkey foreign KEY (apertura_id) references aperturas_dia (id) on delete CASCADE,
  constraint inventario_apertura_producto_id_fkey foreign KEY (producto_id) references productos (id) on delete CASCADE,
  constraint inventario_apertura_cantidad_inicial_check check ((cantidad_inicial >= 0))
) TABLESPACE pg_default;

create index IF not exists idx_inventario_apertura on public.inventario_apertura using btree (apertura_id, producto_id) TABLESPACE pg_default;


create table public.inventario_cierre (
  id serial not null,
  cierre_id integer not null,
  producto_id integer not null,
  cantidad_final integer not null default 0,
  cantidad_sobrantes integer not null default 0,
  cantidad_vencido integer not null default 0,
  created_at timestamp with time zone not null default now(),
  constraint inventario_cierre_pkey primary key (id),
  constraint inventario_cierre_cierre_id_producto_id_key unique (cierre_id, producto_id),
  constraint inventario_cierre_cierre_id_fkey foreign KEY (cierre_id) references cierres_dia (id) on delete CASCADE,
  constraint inventario_cierre_producto_id_fkey foreign KEY (producto_id) references productos (id) on delete CASCADE,
  constraint inventario_cierre_cantidad_vencido_check check ((cantidad_vencido >= 0)),
  constraint inventario_cierre_cantidad_sobrantes_check check ((cantidad_sobrantes >= 0)),
  constraint inventario_cierre_cantidad_final_check check ((cantidad_final >= 0))
) TABLESPACE pg_default;


create table public.productos (
  id serial not null,
  nombre character varying(100) not null,
  descripcion character varying(255) null,
  categoria_id integer null,
  precio numeric(10, 2) null default 0.00,
  unidad_medida character varying(20) null default 'unidad'::character varying,
  activo boolean null default true,
  created_at timestamp with time zone null default now(),
  updated_at timestamp with time zone null default now(),
  constraint productos_pkey primary key (id),
  constraint productos_categoria_id_fkey foreign KEY (categoria_id) references categorias (id) on delete set null
) TABLESPACE pg_default;


create table public.recarga_detalles (
  id serial not null,
  recarga_id integer not null,
  producto_id integer not null,
  cantidad_anterior integer not null default 0,
  cantidad_recargada integer not null,
  cantidad_final integer not null,
  precio_unitario numeric(10, 2) null,
  costo_total numeric(10, 2) null,
  created_at timestamp with time zone not null default now(),
  constraint recarga_detalles_pkey primary key (id),
  constraint recarga_detalles_recarga_id_fkey foreign KEY (recarga_id) references recargas_inventario (id) on delete CASCADE,
  constraint recarga_detalles_producto_id_fkey foreign KEY (producto_id) references productos (id) on delete RESTRICT,
  constraint recarga_detalles_costo_total_check check ((costo_total >= (0)::numeric)),
  constraint recarga_detalles_cantidad_final_check check ((cantidad_final >= 0)),
  constraint recarga_detalles_precio_unitario_check check ((precio_unitario >= (0)::numeric)),
  constraint recarga_detalles_cantidad_anterior_check check ((cantidad_anterior >= 0)),
  constraint recarga_detalles_cantidad_recargada_check check ((cantidad_recargada > 0))
) TABLESPACE pg_default;


create table public.recargas_inventario (
  id serial not null,
  sucursal_id integer not null,
  usuario_id bigint not null,
  fecha_recarga date not null default CURRENT_DATE,
  hora_recarga time without time zone not null default CURRENT_TIME,
  total_productos integer not null default 0,
  estado character varying(20) not null default 'completada'::character varying,
  observaciones text null,
  sincronizado boolean not null default true,
  created_at timestamp with time zone not null default now(),
  updated_at timestamp with time zone not null default now(),
  constraint recargas_inventario_pkey primary key (id),
  constraint recargas_inventario_sucursal_id_fkey foreign KEY (sucursal_id) references sucursales (id) on delete CASCADE,
  constraint recargas_inventario_usuario_id_fkey foreign KEY (usuario_id) references users (id) on delete RESTRICT,
  constraint recargas_inventario_estado_check check (
    (
      (estado)::text = any (
        (
          array[
            'completada'::character varying,
            'pendiente'::character varying,
            'cancelada'::character varying
          ]
        )::text[]
      )
    )
  ),
  constraint recargas_inventario_total_productos_check check ((total_productos >= 0))
) TABLESPACE pg_default;

create trigger update_recargas_inventario_updated_at BEFORE
update on recargas_inventario for EACH row
execute FUNCTION update_updated_at_column ();


create table public.sucursales (
  id serial not null,
  nombre character varying(100) not null,
  direccion character varying(255) null,
  telefono character varying(20) null,
  activa boolean null default true,
  created_at timestamp with time zone null default now(),
  updated_at timestamp with time zone null default now(),
  constraint sucursales_pkey primary key (id),
  constraint sucursales_nombre_key unique (nombre)
) TABLESPACE pg_default;

create table public.users (
  id bigint generated by default as identity not null,
  user_id text not null,
  access_key text null,
  sucursal integer null,
  type integer null,
  constraint users_pkey primary key (id),
  constraint users_sucursal_fkey foreign KEY (sucursal) references sucursales (id)
) TABLESPACE pg_default;


create table public.venta_detalles (
  id serial not null,
  venta_id integer not null,
  producto_id integer not null,
  cantidad integer not null default 1,
  precio_unitario numeric(10, 2) not null,
  precio_total numeric(10, 2) not null,
  descuento numeric(10, 2) not null default 0.00,
  created_at timestamp with time zone not null default now(),
  constraint venta_detalles_pkey primary key (id),
  constraint venta_detalles_producto_id_fkey foreign KEY (producto_id) references productos (id) on delete RESTRICT,
  constraint venta_detalles_venta_id_fkey foreign KEY (venta_id) references ventas (id) on delete CASCADE,
  constraint venta_detalles_precio_unitario_check check ((precio_unitario >= (0)::numeric)),
  constraint venta_detalles_precio_total_check check ((precio_total >= (0)::numeric)),
  constraint venta_detalles_descuento_check check ((descuento >= (0)::numeric)),
  constraint venta_detalles_cantidad_check check ((cantidad > 0))
) TABLESPACE pg_default;

create table public.ventas (
  id serial not null,
  sucursal_id integer not null,
  usuario_id bigint not null,
  fecha_venta date not null default CURRENT_DATE,
  hora_venta time without time zone not null default CURRENT_TIME,
  total numeric(10, 2) not null default 0.00,
  subtotal numeric(10, 2) not null default 0.00,
  descuento numeric(10, 2) not null default 0.00,
  impuesto numeric(10, 2) not null default 0.00,
  metodo_pago character varying(50) null default 'efectivo'::character varying,
  estado character varying(20) not null default 'completada'::character varying,
  numero_ticket character varying(50) null,
  observaciones text null,
  sincronizado boolean not null default true,
  created_at timestamp with time zone not null default now(),
  updated_at timestamp with time zone not null default now(),
  constraint ventas_pkey primary key (id),
  constraint ventas_usuario_id_fkey foreign KEY (usuario_id) references users (id) on delete RESTRICT,
  constraint ventas_sucursal_id_fkey foreign KEY (sucursal_id) references sucursales (id) on delete CASCADE,
  constraint ventas_metodo_pago_check check (
    (
      (metodo_pago)::text = any (
        (
          array[
            'efectivo'::character varying,
            'tarjeta'::character varying,
            'transferencia'::character varying,
            'mixto'::character varying
          ]
        )::text[]
      )
    )
  ),
  constraint ventas_estado_check check (
    (
      (estado)::text = any (
        (
          array[
            'completada'::character varying,
            'cancelada'::character varying,
            'pendiente'::character varying,
            'reembolsada'::character varying
          ]
        )::text[]
      )
    )
  ),
  constraint ventas_subtotal_check check ((subtotal >= (0)::numeric)),
  constraint ventas_descuento_check check ((descuento >= (0)::numeric)),
  constraint ventas_total_check check ((total >= (0)::numeric)),
  constraint ventas_impuesto_check check ((impuesto >= (0)::numeric))
) TABLESPACE pg_default;

create trigger update_ventas_updated_at BEFORE
update on ventas for EACH row
execute FUNCTION update_updated_at_column ();


create view public.vista_cierres_diarios as
select
  c.sucursal_id,
  s.nombre as sucursal_nombre,
  c.fecha_cierre,
  count(c.id) as total_cierres,
  sum(c.total_productos) as total_productos_cerrados,
  sum(c.total_desperdicio) as total_desperdicio,
  sum(c.total_ventas) as total_ventas_cierre,
  count(distinct ic.producto_id) as productos_distintos,
  count(distinct c.usuario_cierre) as usuarios_que_cerraron
from
  cierres_dia c
  join sucursales s on c.sucursal_id = s.id
  left join inventario_cierre ic on c.id = ic.cierre_id
where
  c.estado::text = 'completado'::text
group by
  c.sucursal_id,
  s.nombre,
  c.fecha_cierre
order by
  c.fecha_cierre desc,
  c.sucursal_id;


  create view public.vista_productos_mas_recargados as
select
  p.id as producto_id,
  p.nombre as producto_nombre,
  c.nombre as categoria_nombre,
  count(rd.id) as veces_recargado,
  sum(rd.cantidad_recargada) as total_unidades_recargadas,
  avg(rd.precio_unitario) as precio_promedio_compra,
  min(rd.precio_unitario) as precio_minimo_compra,
  max(rd.precio_unitario) as precio_maximo_compra,
  sum(rd.costo_total) as costo_total_compras
from
  recarga_detalles rd
  join productos p on rd.producto_id = p.id
  left join categorias c on p.categoria_id = c.id
  join recargas_inventario r on rd.recarga_id = r.id
where
  r.estado::text = 'completada'::text
group by
  p.id,
  p.nombre,
  c.nombre
order by
  (sum(rd.cantidad_recargada)) desc;

  create view public.vista_productos_mas_vendidos as
select
  p.id as producto_id,
  p.nombre as producto_nombre,
  c.nombre as categoria_nombre,
  count(vd.id) as veces_vendido,
  sum(vd.cantidad) as total_unidades_vendidas,
  sum(vd.precio_total) as total_ingresos_producto,
  avg(vd.precio_unitario) as precio_promedio,
  min(vd.precio_unitario) as precio_minimo,
  max(vd.precio_unitario) as precio_maximo,
  sum(vd.cantidad::numeric * vd.precio_unitario) as valor_total_vendido
from
  venta_detalles vd
  join productos p on vd.producto_id = p.id
  left join categorias c on p.categoria_id = c.id
  join ventas v on vd.venta_id = v.id
where
  v.estado::text = 'completada'::text
group by
  p.id,
  p.nombre,
  c.nombre
order by
  (sum(vd.cantidad)) desc;


  create view public.vista_recargas_diarias as
select
  r.sucursal_id,
  s.nombre as sucursal_nombre,
  r.fecha_recarga,
  count(r.id) as total_recargas,
  sum(r.total_productos) as total_productos_recargados,
  count(distinct rd.producto_id) as productos_distintos,
  sum(rd.cantidad_recargada) as total_unidades_recargadas,
  sum(rd.costo_total) as costo_total_recargas,
  count(distinct r.usuario_id) as usuarios_que_recargaron
from
  recargas_inventario r
  join sucursales s on r.sucursal_id = s.id
  left join recarga_detalles rd on r.id = rd.recarga_id
where
  r.estado::text = 'completada'::text
group by
  r.sucursal_id,
  s.nombre,
  r.fecha_recarga
order by
  r.fecha_recarga desc,
  r.sucursal_id;


  create view public.vista_rendimiento_cajeros as
select
  u.id as usuario_id,
  u.user_id as usuario_nombre,
  v.sucursal_id,
  s.nombre as sucursal_nombre,
  count(v.id) as total_ventas,
  sum(v.total) as total_ingresos,
  avg(v.total) as promedio_venta,
  min(v.fecha_venta) as primera_venta,
  max(v.fecha_venta) as ultima_venta,
  count(distinct v.fecha_venta) as dias_trabajados
from
  ventas v
  join users u on v.usuario_id = u.id
  join sucursales s on v.sucursal_id = s.id
where
  v.estado::text = 'completada'::text
group by
  u.id,
  u.user_id,
  v.sucursal_id,
  s.nombre
order by
  (sum(v.total)) desc;


  create view public.vista_ventas_diarias as
select
  v.sucursal_id,
  s.nombre as sucursal_nombre,
  v.fecha_venta,
  count(v.id) as total_ventas,
  sum(v.total) as total_ingresos,
  sum(v.subtotal) as total_subtotal,
  sum(v.descuento) as total_descuentos,
  sum(v.impuesto) as total_impuestos,
  avg(v.total) as promedio_venta,
  min(v.total) as venta_minima,
  max(v.total) as venta_maxima,
  count(distinct v.usuario_id) as total_cajeros,
  count(distinct vd.producto_id) as productos_vendidos,
  sum(vd.cantidad) as total_unidades_vendidas
from
  ventas v
  join sucursales s on v.sucursal_id = s.id
  left join venta_detalles vd on v.id = vd.venta_id
where
  v.estado::text = 'completada'::text
group by
  v.sucursal_id,
  s.nombre,
  v.fecha_venta
order by
  v.fecha_venta desc,
  v.sucursal_id;


  create view public.vista_ventas_por_hora as
select
  EXTRACT(
    hour
    from
      v.hora_venta
  ) as hora_del_dia,
  count(v.id) as total_ventas,
  sum(v.total) as total_ingresos,
  avg(v.total) as promedio_venta,
  sum(vd.cantidad) as total_unidades_vendidas
from
  ventas v
  left join venta_detalles vd on v.id = vd.venta_id
where
  v.estado::text = 'completada'::text
group by
  (
    EXTRACT(
      hour
      from
        v.hora_venta
    )
  )
order by
  (
    EXTRACT(
      hour
      from
        v.hora_venta
    )
  );


-- Tabla para pedidos a fábrica
create table public.pedidos_fabrica (
  id serial not null,
  sucursal_id integer not null,
  usuario_id bigint not null,
  fecha_pedido date not null default CURRENT_DATE,
  hora_pedido time without time zone not null default CURRENT_TIME,
  total_items integer not null default 0,
  estado character varying(20) not null default 'pendiente'::character varying,
  numero_pedido character varying(50) null,
  observaciones text null,
  sincronizado boolean not null default true,
  created_at timestamp with time zone not null default now(),
  updated_at timestamp with time zone not null default now(),
  constraint pedidos_fabrica_pkey primary key (id),
  constraint pedidos_fabrica_sucursal_id_fkey foreign KEY (sucursal_id) references sucursales (id) on delete CASCADE,
  constraint pedidos_fabrica_usuario_id_fkey foreign KEY (usuario_id) references users (id) on delete RESTRICT,
  constraint pedidos_fabrica_total_items_check check ((total_items >= 0)),
  constraint pedidos_fabrica_estado_check check (
    (
      (estado)::text = any (
        (
          array[
            'pendiente'::character varying,
            'en_preparacion'::character varying,
            'enviado'::character varying,
            'entregado'::character varying,
            'cancelado'::character varying
          ]
        )::text[]
      )
    )
  )
) TABLESPACE pg_default;

create trigger update_pedidos_fabrica_updated_at BEFORE
update on pedidos_fabrica for EACH row
execute FUNCTION update_updated_at_column ();

create index IF not exists idx_pedidos_fabrica_sucursal on public.pedidos_fabrica using btree (sucursal_id, created_at desc) TABLESPACE pg_default;
create index IF not exists idx_pedidos_fabrica_estado on public.pedidos_fabrica using btree (estado) TABLESPACE pg_default;

-- NOTA: Si la tabla ya existe y necesitas agregar el estado 'en_preparacion', ejecuta:
-- ALTER TABLE public.pedidos_fabrica DROP CONSTRAINT IF EXISTS pedidos_fabrica_estado_check;
-- ALTER TABLE public.pedidos_fabrica ADD CONSTRAINT pedidos_fabrica_estado_check CHECK (
--   (estado)::text = ANY (ARRAY['pendiente'::character varying, 'en_preparacion'::character varying, 'enviado'::character varying, 'entregado'::character varying, 'cancelado'::character varying]::text[])
-- );


-- Tabla para detalles de pedidos a fábrica
create table public.pedido_fabrica_detalles (
  id serial not null,
  pedido_id integer not null,
  producto_id integer not null,
  cantidad integer not null default 1,
  created_at timestamp with time zone not null default now(),
  constraint pedido_fabrica_detalles_pkey primary key (id),
  constraint pedido_fabrica_detalles_pedido_id_fkey foreign KEY (pedido_id) references pedidos_fabrica (id) on delete CASCADE,
  constraint pedido_fabrica_detalles_producto_id_fkey foreign KEY (producto_id) references productos (id) on delete RESTRICT,
  constraint pedido_fabrica_detalles_cantidad_check check ((cantidad > 0))
) TABLESPACE pg_default;

create index IF not exists idx_pedido_fabrica_detalles_pedido on public.pedido_fabrica_detalles using btree (pedido_id) TABLESPACE pg_default;
create index IF not exists idx_pedido_fabrica_detalles_producto on public.pedido_fabrica_detalles using btree (producto_id) TABLESPACE pg_default;


-- Tabla para pedidos de clientes (desde WhatsApp)
create table public.pedidos_clientes (
  id serial not null,
  cliente_nombre character varying(100) not null,
  cliente_telefono character varying(20) null,
  direccion_entrega character varying(255) not null,
  fecha_pedido date not null default CURRENT_DATE,
  hora_pedido time without time zone not null default CURRENT_TIME,
  total_items integer not null default 0,
  total numeric(10, 2) not null default 0.00,
  estado character varying(20) not null default 'pendiente'::character varying,
  numero_pedido character varying(50) null,
  observaciones text null,
  metodo_pago character varying(50) null default 'efectivo'::character varying,
  sincronizado boolean not null default true,
  created_at timestamp with time zone not null default now(),
  updated_at timestamp with time zone not null default now(),
  constraint pedidos_clientes_pkey primary key (id),
  constraint pedidos_clientes_total_items_check check ((total_items >= 0)),
  constraint pedidos_clientes_total_check check ((total >= (0)::numeric)),
  constraint pedidos_clientes_estado_check check (
    (
      (estado)::text = any (
        (
          array[
            'pendiente'::character varying,
            'en_preparacion'::character varying,
            'enviado'::character varying,
            'entregado'::character varying,
            'cancelado'::character varying
          ]
        )::text[]
      )
    )
  ),
  constraint pedidos_clientes_metodo_pago_check check (
    (
      (metodo_pago)::text = any (
        (
          array[
            'efectivo'::character varying,
            'tarjeta'::character varying,
            'transferencia'::character varying,
            'mixto'::character varying
          ]
        )::text[]
      )
    )
  )
) TABLESPACE pg_default;

create trigger update_pedidos_clientes_updated_at BEFORE
update on pedidos_clientes for EACH row
execute FUNCTION update_updated_at_column ();

create index IF not exists idx_pedidos_clientes_estado on public.pedidos_clientes using btree (estado) TABLESPACE pg_default;
create index IF not exists idx_pedidos_clientes_fecha on public.pedidos_clientes using btree (fecha_pedido desc, created_at desc) TABLESPACE pg_default;


-- Tabla para detalles de pedidos de clientes
create table public.pedido_cliente_detalles (
  id serial not null,
  pedido_id integer not null,
  producto_id integer not null,
  cantidad integer not null default 1,
  precio_unitario numeric(10, 2) not null,
  precio_total numeric(10, 2) not null,
  created_at timestamp with time zone not null default now(),
  constraint pedido_cliente_detalles_pkey primary key (id),
  constraint pedido_cliente_detalles_pedido_id_fkey foreign KEY (pedido_id) references pedidos_clientes (id) on delete CASCADE,
  constraint pedido_cliente_detalles_producto_id_fkey foreign KEY (producto_id) references productos (id) on delete RESTRICT,
  constraint pedido_cliente_detalles_cantidad_check check ((cantidad > 0)),
  constraint pedido_cliente_detalles_precio_unitario_check check ((precio_unitario >= (0)::numeric)),
  constraint pedido_cliente_detalles_precio_total_check check ((precio_total >= (0)::numeric))
) TABLESPACE pg_default;

create index IF not exists idx_pedido_cliente_detalles_pedido on public.pedido_cliente_detalles using btree (pedido_id) TABLESPACE pg_default;
create index IF not exists idx_pedido_cliente_detalles_producto on public.pedido_cliente_detalles using btree (producto_id) TABLESPACE pg_default;


-- Tabla para empleados de producción
create table public.empleados (
  id serial not null,
  nombre character varying(100) not null,
  telefono character varying(20) null,
  email character varying(100) null,
  activo boolean not null default true,
  created_at timestamp with time zone not null default now(),
  updated_at timestamp with time zone not null default now(),
  constraint empleados_pkey primary key (id),
  constraint empleados_nombre_key unique (nombre)
) TABLESPACE pg_default;

create trigger update_empleados_updated_at BEFORE
update on empleados for EACH row
execute FUNCTION update_updated_at_column ();

create index IF not exists idx_empleados_activo on public.empleados using btree (activo) TABLESPACE pg_default;


-- Tabla para producción por empleado
create table public.produccion_empleado (
  id serial not null,
  empleado_id integer not null,
  producto_id integer not null,
  cantidad_producida integer not null default 1,
  fecha_produccion date not null default CURRENT_DATE,
  hora_produccion time without time zone not null default CURRENT_TIME,
  pedido_fabrica_id integer null,
  pedido_cliente_id integer null,
  observaciones text null,
  created_at timestamp with time zone not null default now(),
  constraint produccion_empleado_pkey primary key (id),
  constraint produccion_empleado_empleado_id_fkey foreign KEY (empleado_id) references empleados (id) on delete RESTRICT,
  constraint produccion_empleado_producto_id_fkey foreign KEY (producto_id) references productos (id) on delete RESTRICT,
  constraint produccion_empleado_pedido_fabrica_id_fkey foreign KEY (pedido_fabrica_id) references pedidos_fabrica (id) on delete set null,
  constraint produccion_empleado_pedido_cliente_id_fkey foreign KEY (pedido_cliente_id) references pedidos_clientes (id) on delete set null,
  constraint produccion_empleado_cantidad_producida_check check ((cantidad_producida > 0)),
  constraint produccion_empleado_pedido_check check (
    (pedido_fabrica_id is null and pedido_cliente_id is null) or
    (pedido_fabrica_id is not null and pedido_cliente_id is null) or
    (pedido_fabrica_id is null and pedido_cliente_id is not null)
  )
) TABLESPACE pg_default;

create index IF not exists idx_produccion_empleado_empleado on public.produccion_empleado using btree (empleado_id, fecha_produccion desc) TABLESPACE pg_default;
create index IF not exists idx_produccion_empleado_producto on public.produccion_empleado using btree (producto_id) TABLESPACE pg_default;
create index IF not exists idx_produccion_empleado_fecha on public.produccion_empleado using btree (fecha_produccion desc) TABLESPACE pg_default;
create index IF not exists idx_produccion_empleado_pedido_fabrica on public.produccion_empleado using btree (pedido_fabrica_id) TABLESPACE pg_default;
create index IF not exists idx_produccion_empleado_pedido_cliente on public.produccion_empleado using btree (pedido_cliente_id) TABLESPACE pg_default;