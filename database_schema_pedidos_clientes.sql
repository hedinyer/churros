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
