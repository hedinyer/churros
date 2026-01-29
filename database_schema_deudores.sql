-- Tabla deudores (similar a ventas pero para ventas a fiado)
create table public.deudores (
  id serial not null,
  sucursal_id integer not null,
  usuario_id bigint not null,
  nombre_deudor character varying(100) not null,
  fecha_venta date not null default CURRENT_DATE,
  hora_venta time without time zone not null default CURRENT_TIME,
  total numeric(10, 2) not null default 0.00,
  subtotal numeric(10, 2) not null default 0.00,
  descuento numeric(10, 2) not null default 0.00,
  impuesto numeric(10, 2) not null default 0.00,
  estado character varying(20) not null default 'pendiente'::character varying,
  numero_ticket character varying(50) null,
  observaciones text null,
  sincronizado boolean not null default true,
  created_at timestamp with time zone not null default now(),
  updated_at timestamp with time zone not null default now(),
  constraint deudores_pkey primary key (id),
  constraint deudores_usuario_id_fkey foreign KEY (usuario_id) references users (id) on delete RESTRICT,
  constraint deudores_sucursal_id_fkey foreign KEY (sucursal_id) references sucursales (id) on delete CASCADE,
  constraint deudores_estado_check check (
    (
      (estado)::text = any (
        (
          array[
            'pendiente'::character varying,
            'pagado'::character varying,
            'cancelado'::character varying
          ]
        )::text[]
      )
    )
  ),
  constraint deudores_subtotal_check check ((subtotal >= (0)::numeric)),
  constraint deudores_descuento_check check ((descuento >= (0)::numeric)),
  constraint deudores_total_check check ((total >= (0)::numeric)),
  constraint deudores_impuesto_check check ((impuesto >= (0)::numeric))
) TABLESPACE pg_default;

create index IF not exists idx_deudores_sucursal on public.deudores using btree (sucursal_id, fecha_venta desc) TABLESPACE pg_default;
create index IF not exists idx_deudores_estado on public.deudores using btree (estado) TABLESPACE pg_default;
create index IF not exists idx_deudores_nombre on public.deudores using btree (nombre_deudor) TABLESPACE pg_default;

create trigger update_deudores_updated_at BEFORE
update on deudores for EACH row
execute FUNCTION update_updated_at_column ();

-- Tabla deudor_detalles (similar a venta_detalles)
create table public.deudor_detalles (
  id serial not null,
  deudor_id integer not null,
  producto_id integer not null,
  cantidad integer not null default 1,
  precio_unitario numeric(10, 2) not null,
  precio_total numeric(10, 2) not null,
  descuento numeric(10, 2) not null default 0.00,
  created_at timestamp with time zone not null default now(),
  constraint deudor_detalles_pkey primary key (id),
  constraint deudor_detalles_producto_id_fkey foreign KEY (producto_id) references productos (id) on delete RESTRICT,
  constraint deudor_detalles_deudor_id_fkey foreign KEY (deudor_id) references deudores (id) on delete CASCADE,
  constraint deudor_detalles_precio_unitario_check check ((precio_unitario >= (0)::numeric)),
  constraint deudor_detalles_precio_total_check check ((precio_total >= (0)::numeric)),
  constraint deudor_detalles_descuento_check check ((descuento >= (0)::numeric)),
  constraint deudor_detalles_cantidad_check check ((cantidad > 0))
) TABLESPACE pg_default;

create index IF not exists idx_deudor_detalles_deudor on public.deudor_detalles using btree (deudor_id) TABLESPACE pg_default;
create index IF not exists idx_deudor_detalles_producto on public.deudor_detalles using btree (producto_id) TABLESPACE pg_default;
