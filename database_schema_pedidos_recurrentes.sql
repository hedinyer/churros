-- ============================================
-- ESQUEMA DE BASE DE DATOS PARA PEDIDOS RECURRENTES
-- Sistema POS Churros - Gestión de Pedidos Recurrentes con Precios Especiales
-- ============================================

-- Tabla principal de pedidos recurrentes
create table public.pedidos_recurrentes (
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
  constraint pedidos_recurrentes_pkey primary key (id),
  constraint pedidos_recurrentes_total_items_check check ((total_items >= 0)),
  constraint pedidos_recurrentes_total_check check ((total >= (0)::numeric)),
  constraint pedidos_recurrentes_estado_check check (
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
  constraint pedidos_recurrentes_metodo_pago_check check (
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

create trigger update_pedidos_recurrentes_updated_at BEFORE
update on pedidos_recurrentes for EACH row
execute FUNCTION update_updated_at_column ();

create index IF not exists idx_pedidos_recurrentes_estado on public.pedidos_recurrentes using btree (estado) TABLESPACE pg_default;
create index IF not exists idx_pedidos_recurrentes_fecha on public.pedidos_recurrentes using btree (fecha_pedido desc, created_at desc) TABLESPACE pg_default;
create index IF not exists idx_pedidos_recurrentes_cliente on public.pedidos_recurrentes using btree (cliente_nombre) TABLESPACE pg_default;


-- Tabla para detalles de pedidos recurrentes (con precios especiales)
create table public.pedido_recurrente_detalles (
  id serial not null,
  pedido_id integer not null,
  producto_id integer not null,
  cantidad integer not null default 1,
  precio_unitario numeric(10, 2) not null,
  precio_base numeric(10, 2) not null,
  precio_especial numeric(10, 2) null,
  precio_total numeric(10, 2) not null,
  tiene_precio_especial boolean not null default false,
  created_at timestamp with time zone not null default now(),
  constraint pedido_recurrente_detalles_pkey primary key (id),
  constraint pedido_recurrente_detalles_pedido_id_fkey foreign KEY (pedido_id) references pedidos_recurrentes (id) on delete CASCADE,
  constraint pedido_recurrente_detalles_producto_id_fkey foreign KEY (producto_id) references productos (id) on delete RESTRICT,
  constraint pedido_recurrente_detalles_cantidad_check check ((cantidad > 0)),
  constraint pedido_recurrente_detalles_precio_unitario_check check ((precio_unitario >= (0)::numeric)),
  constraint pedido_recurrente_detalles_precio_base_check check ((precio_base >= (0)::numeric)),
  constraint pedido_recurrente_detalles_precio_especial_check check ((precio_especial is null or precio_especial >= (0)::numeric)),
  constraint pedido_recurrente_detalles_precio_total_check check ((precio_total >= (0)::numeric))
) TABLESPACE pg_default;

create index IF not exists idx_pedido_recurrente_detalles_pedido on public.pedido_recurrente_detalles using btree (pedido_id) TABLESPACE pg_default;
create index IF not exists idx_pedido_recurrente_detalles_producto on public.pedido_recurrente_detalles using btree (producto_id) TABLESPACE pg_default;
