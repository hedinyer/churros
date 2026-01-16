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
