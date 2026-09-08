SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- Name: btree_gist; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS btree_gist WITH SCHEMA public;


--
-- Name: EXTENSION btree_gist; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON EXTENSION btree_gist IS 'support for indexing common datatypes in GiST';


SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: appointment_services; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.appointment_services (
    id bigint NOT NULL,
    appointment_id bigint NOT NULL,
    service_id bigint NOT NULL,
    "position" integer NOT NULL,
    service_name text NOT NULL,
    duration_minutes integer NOT NULL,
    quoted_price numeric(14,2) NOT NULL,
    CONSTRAINT appointment_services_duration_positive CHECK ((duration_minutes > 0)),
    CONSTRAINT appointment_services_name_present CHECK ((btrim(service_name) <> ''::text)),
    CONSTRAINT appointment_services_position_positive CHECK (("position" > 0)),
    CONSTRAINT appointment_services_quoted_price_range CHECK (((quoted_price >= (0)::numeric) AND (quoted_price < 'Infinity'::numeric)))
);


--
-- Name: TABLE appointment_services; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.appointment_services IS 'Servicios ordenados dentro de la cita. Todos los atiende su mismo empleado. La aplicacion valida al menos uno y que sus duraciones quepan en el intervalo reservado.';


--
-- Name: COLUMN appointment_services.service_name; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.appointment_services.service_name IS 'Nombre al reservar; conserva el historial';


--
-- Name: COLUMN appointment_services.duration_minutes; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.appointment_services.duration_minutes IS 'Duracion acordada para esta reserva';


--
-- Name: COLUMN appointment_services.quoted_price; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.appointment_services.quoted_price IS 'Precio pactado antes de impuestos en la moneda de la cita';


--
-- Name: appointment_services_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.appointment_services_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: appointment_services_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.appointment_services_id_seq OWNED BY public.appointment_services.id;


--
-- Name: appointments; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.appointments (
    id bigint NOT NULL,
    client_id bigint NOT NULL,
    employee_id bigint NOT NULL,
    created_by_id bigint,
    currency character varying(3) DEFAULT 'MXN'::character varying NOT NULL,
    starts_at timestamp with time zone NOT NULL,
    ends_at timestamp with time zone NOT NULL,
    status text DEFAULT 'scheduled'::text NOT NULL,
    notes text,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT appointments_currency_format CHECK (((currency)::text ~ '^[A-Z]{3}$'::text)),
    CONSTRAINT appointments_finite_span CHECK (((ends_at > starts_at) AND isfinite(starts_at) AND isfinite(ends_at))),
    CONSTRAINT appointments_status_allowed CHECK ((status = ANY (ARRAY['scheduled'::text, 'completed'::text, 'cancelled'::text, 'no_show'::text])))
);


--
-- Name: TABLE appointments; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.appointments IS 'Reserva individual. Un cliente y un empleado. El SQL agrega exclusion de traslapes por empleado. La aplicacion crea cita y servicios en una transaccion.';


--
-- Name: COLUMN appointments.currency; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.appointments.currency IS 'Moneda pactada de los servicios; copiar configuracion al reservar';


--
-- Name: appointments_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.appointments_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: appointments_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.appointments_id_seq OWNED BY public.appointments.id;


--
-- Name: ar_internal_metadata; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.ar_internal_metadata (
    key character varying NOT NULL,
    value character varying,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: business_settings; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.business_settings (
    id smallint DEFAULT 1 NOT NULL,
    name text NOT NULL,
    time_zone text DEFAULT 'UTC'::text NOT NULL,
    currency character varying(3) DEFAULT 'MXN'::character varying NOT NULL,
    usd_exchange_rate numeric(12,6),
    CONSTRAINT business_settings_currency_format CHECK (((currency)::text ~ '^[A-Z]{3}$'::text)),
    CONSTRAINT business_settings_name_present CHECK ((btrim(name) <> ''::text)),
    CONSTRAINT business_settings_singleton CHECK ((id = 1)),
    CONSTRAINT business_settings_time_zone_present CHECK ((btrim(time_zone) <> ''::text)),
    CONSTRAINT settings_exchange_rate_positive CHECK (((usd_exchange_rate > (0)::numeric) AND (usd_exchange_rate < 'Infinity'::numeric)))
);


--
-- Name: TABLE business_settings; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.business_settings IS 'Configuracion de una sola empresa por base de datos. Maximo una fila; crearla al configurar la aplicacion. No es un modelo multiempresa compartido.';


--
-- Name: COLUMN business_settings.time_zone; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.business_settings.time_zone IS 'Zona IANA del negocio; configurar antes de reservar';


--
-- Name: COLUMN business_settings.currency; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.business_settings.currency IS 'Moneda de operacion. No cambiar sin convertir el catalogo y revisar cotizaciones abiertas';


--
-- Name: clients; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.clients (
    id bigint NOT NULL,
    name text NOT NULL,
    phone text,
    email text,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT clients_name_present CHECK ((btrim(name) <> ''::text))
);


--
-- Name: TABLE clients; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.clients IS 'Persona que reserva. Telefono y email no son unicos: pueden compartirse.';


--
-- Name: clients_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.clients_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: clients_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.clients_id_seq OWNED BY public.clients.id;


--
-- Name: employee_services; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.employee_services (
    id bigint NOT NULL,
    employee_id bigint NOT NULL,
    service_id bigint NOT NULL
);


--
-- Name: TABLE employee_services; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.employee_services IS 'Servicios que puede realizar cada empleado. La aplicacion verifica esta asignacion al reservar.';


--
-- Name: employee_services_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.employee_services_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: employee_services_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.employee_services_id_seq OWNED BY public.employee_services.id;


--
-- Name: employee_time_off; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.employee_time_off (
    id bigint NOT NULL,
    employee_id bigint NOT NULL,
    starts_at timestamp with time zone NOT NULL,
    ends_at timestamp with time zone NOT NULL,
    reason text,
    created_by_id bigint NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT employee_time_off_finite_span CHECK (((ends_at > starts_at) AND isfinite(starts_at) AND isfinite(ends_at)))
);


--
-- Name: TABLE employee_time_off; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.employee_time_off IS 'Ausencias, vacaciones y bloqueos puntuales. La aplicacion debe impedir reservar dentro de estos intervalos y revisar citas al registrar una ausencia.';


--
-- Name: employee_time_off_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.employee_time_off_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: employee_time_off_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.employee_time_off_id_seq OWNED BY public.employee_time_off.id;


--
-- Name: employee_working_hours; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.employee_working_hours (
    id bigint NOT NULL,
    employee_id bigint NOT NULL,
    weekday smallint NOT NULL,
    starts_at time without time zone NOT NULL,
    ends_at time without time zone NOT NULL,
    CONSTRAINT working_hours_positive_span CHECK ((ends_at > starts_at)),
    CONSTRAINT working_hours_weekday_iso CHECK (((weekday >= 1) AND (weekday <= 7)))
);


--
-- Name: TABLE employee_working_hours; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.employee_working_hours IS 'Horario semanal actual en la zona del negocio. Varios tramos por dia permiten descansos. Turnos nocturnos se dividen por dia; 24:00 representa fin de dia.';


--
-- Name: COLUMN employee_working_hours.weekday; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.employee_working_hours.weekday IS 'ISO: 1=lunes, 7=domingo';


--
-- Name: employee_working_hours_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.employee_working_hours_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: employee_working_hours_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.employee_working_hours_id_seq OWNED BY public.employee_working_hours.id;


--
-- Name: employees; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.employees (
    id bigint NOT NULL,
    user_id bigint,
    name text NOT NULL,
    active boolean DEFAULT true NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT employees_name_present CHECK ((btrim(name) <> ''::text))
);


--
-- Name: TABLE employees; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.employees IS 'Empleado que atiende. Su perfil laboral se separa de la cuenta de acceso opcional. Administradores y recepcionistas pueden tener cuenta sin ser empleados.';


--
-- Name: employees_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.employees_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: employees_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.employees_id_seq OWNED BY public.employees.id;


--
-- Name: payment_attempts; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.payment_attempts (
    id bigint NOT NULL,
    sale_id bigint NOT NULL,
    registered_by_id bigint NOT NULL,
    idempotency_key uuid NOT NULL,
    amount numeric(14,2) NOT NULL,
    currency character varying(3) NOT NULL,
    method text NOT NULL,
    status text DEFAULT 'pending'::text NOT NULL,
    external_reference text,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT payment_attempts_amount_range CHECK (((amount > (0)::numeric) AND (amount < 'Infinity'::numeric))),
    CONSTRAINT payment_attempts_currency CHECK (((currency)::text ~ '^[A-Z]{3}$'::text)),
    CONSTRAINT payment_attempts_method CHECK ((method = ANY (ARRAY['card'::text, 'transfer'::text]))),
    CONSTRAINT payment_attempts_status CHECK ((status = ANY (ARRAY['pending'::text, 'succeeded'::text, 'failed'::text])))
);


--
-- Name: payment_attempts_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.payment_attempts_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: payment_attempts_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.payment_attempts_id_seq OWNED BY public.payment_attempts.id;


--
-- Name: payments; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.payments (
    id bigint NOT NULL,
    sale_id bigint NOT NULL,
    registered_by_id bigint NOT NULL,
    kind text DEFAULT 'receipt'::text NOT NULL,
    original_payment_id bigint,
    method text NOT NULL,
    amount numeric(14,2) NOT NULL,
    tendered_amount numeric(14,2),
    external_reference text,
    reason text,
    idempotency_key uuid NOT NULL,
    occurred_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT payments_amount_range CHECK (((amount > (0)::numeric) AND (amount < 'Infinity'::numeric))),
    CONSTRAINT payments_cash_tendered CHECK ((((kind = 'receipt'::text) AND (method = 'cash'::text) AND (tendered_amount IS NOT NULL) AND (tendered_amount >= amount) AND (tendered_amount < 'Infinity'::numeric)) OR (((kind <> 'receipt'::text) OR (method <> 'cash'::text)) AND (tendered_amount IS NULL)))),
    CONSTRAINT payments_kind_allowed CHECK ((kind = ANY (ARRAY['receipt'::text, 'refund'::text]))),
    CONSTRAINT payments_method_allowed CHECK ((method = ANY (ARRAY['cash'::text, 'card'::text, 'transfer'::text]))),
    CONSTRAINT payments_original_not_self CHECK (((original_payment_id IS NULL) OR (original_payment_id <> id))),
    CONSTRAINT payments_refund_has_original CHECK (((kind = 'refund'::text) = (original_payment_id IS NOT NULL))),
    CONSTRAINT payments_refund_reason_present CHECK (((kind <> 'refund'::text) OR ((reason IS NOT NULL) AND (btrim(reason) <> ''::text))))
);


--
-- Name: TABLE payments; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.payments IS 'Solo movimientos confirmados. Multiples filas permiten anticipos, abonos y pagos mixtos. La aplicacion impide sobrecobros, devoluciones excesivas y cambios en movimientos confirmados; implementa permisos e idempotencia.';


--
-- Name: COLUMN payments.kind; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.payments.kind IS 'receipt = cobro; refund = devolucion de dinero';


--
-- Name: COLUMN payments.original_payment_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.payments.original_payment_id IS 'Obligatorio para refund; referencia un cobro de esta misma venta';


--
-- Name: COLUMN payments.method; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.payments.method IS 'cash, card, transfer';


--
-- Name: COLUMN payments.amount; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.payments.amount IS 'Neto aplicado o devuelto; siempre positivo; moneda de la venta';


--
-- Name: COLUMN payments.tendered_amount; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.payments.tendered_amount IS 'Solo cobro en efectivo. Cambio = tendered_amount - amount';


--
-- Name: COLUMN payments.reason; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.payments.reason IS 'Obligatorio para devoluciones';


--
-- Name: COLUMN payments.idempotency_key; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.payments.idempotency_key IS 'Generada por el cliente de la operacion y reutilizada en cada reintento';


--
-- Name: payments_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.payments_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: payments_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.payments_id_seq OWNED BY public.payments.id;


--
-- Name: roles; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.roles (
    id bigint NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    name character varying NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    code text NOT NULL,
    CONSTRAINT roles_code_name_present CHECK (((btrim(code) <> ''::text) AND (btrim((name)::text) <> ''::text)))
);


--
-- Name: roles_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.roles_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: roles_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.roles_id_seq OWNED BY public.roles.id;


--
-- Name: sale_balances; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.sale_balances AS
SELECT
    NULL::bigint AS sale_id,
    NULL::character varying(3) AS currency,
    NULL::text AS status,
    NULL::numeric(14,2) AS original_total,
    NULL::numeric AS amount_due,
    NULL::numeric AS received,
    NULL::numeric AS refunded,
    NULL::numeric AS balance;


--
-- Name: VIEW sale_balances; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON VIEW public.sale_balances IS 'Positivo: por cobrar; negativo: a favor del cliente. Draft es provisional. La vista calcula saldos, no impide sobrecobros ni devoluciones excesivas.';


--
-- Name: sale_items; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.sale_items (
    id bigint NOT NULL,
    sale_id bigint NOT NULL,
    service_id bigint NOT NULL,
    appointment_service_id bigint,
    description text NOT NULL,
    quantity integer DEFAULT 1 NOT NULL,
    unit_price numeric(14,2) NOT NULL,
    discount_amount numeric(14,2) DEFAULT 0.0 NOT NULL,
    tax_rate numeric(7,6) DEFAULT 0.0 NOT NULL,
    tax_amount numeric(14,2) DEFAULT 0.0 NOT NULL,
    total numeric(14,2) NOT NULL,
    employee_id bigint,
    CONSTRAINT sale_items_description_quantity CHECK (((btrim(description) <> ''::text) AND (quantity > 0))),
    CONSTRAINT sale_items_discount_range CHECK (((discount_amount >= (0)::numeric) AND (discount_amount <= ((quantity)::numeric * unit_price)))),
    CONSTRAINT sale_items_tax_arithmetic CHECK ((tax_amount = round(((((quantity)::numeric * unit_price) - discount_amount) * tax_rate), 2))),
    CONSTRAINT sale_items_tax_rate_range CHECK (((tax_rate >= (0)::numeric) AND (tax_rate <= (1)::numeric))),
    CONSTRAINT sale_items_total_arithmetic CHECK ((total = ((((quantity)::numeric * unit_price) - discount_amount) + tax_amount))),
    CONSTRAINT sale_items_unit_price_range CHECK (((unit_price >= (0)::numeric) AND (unit_price < 'Infinity'::numeric)))
);


--
-- Name: TABLE sale_items; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.sale_items IS 'Partida historica. La aplicacion verifica que el servicio reservado pertenezca a la cita de esta venta y al mismo servicio. No recalcular con precios actuales del catalogo.';


--
-- Name: COLUMN sale_items.description; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.sale_items.description IS 'Nombre o descripcion al vender';


--
-- Name: COLUMN sale_items.unit_price; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.sale_items.unit_price IS 'Antes de impuestos; moneda de la venta';


--
-- Name: COLUMN sale_items.discount_amount; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.sale_items.discount_amount IS 'Descuento total de esta partida';


--
-- Name: COLUMN sale_items.tax_rate; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.sale_items.tax_rate IS 'Fraccion: 0.16 = 16 por ciento';


--
-- Name: sale_items_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.sale_items_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: sale_items_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.sale_items_id_seq OWNED BY public.sale_items.id;


--
-- Name: sales; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.sales (
    id bigint NOT NULL,
    appointment_id bigint,
    client_id bigint NOT NULL,
    created_by_id bigint NOT NULL,
    currency character varying(3) DEFAULT 'MXN'::character varying NOT NULL,
    status text DEFAULT 'draft'::text NOT NULL,
    subtotal numeric(14,2) DEFAULT 0.0 NOT NULL,
    discount_total numeric(14,2) DEFAULT 0.0 NOT NULL,
    tax_total numeric(14,2) DEFAULT 0.0 NOT NULL,
    total numeric(14,2) DEFAULT 0.0 NOT NULL,
    notes text,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    exchange_rate numeric(12,6),
    discount_percent numeric(5,2) DEFAULT 0.0 NOT NULL,
    checkout_key uuid,
    CONSTRAINT sales_currency_format CHECK (((currency)::text ~ '^[A-Z]{3}$'::text)),
    CONSTRAINT sales_discount_percent_range CHECK (((discount_percent >= (0)::numeric) AND (discount_percent <= (100)::numeric))),
    CONSTRAINT sales_discount_range CHECK (((discount_total >= (0)::numeric) AND (discount_total <= subtotal))),
    CONSTRAINT sales_exchange_rate_positive CHECK (((exchange_rate > (0)::numeric) AND (exchange_rate < 'Infinity'::numeric))),
    CONSTRAINT sales_status_allowed CHECK ((status = ANY (ARRAY['draft'::text, 'posted'::text, 'cancelled'::text]))),
    CONSTRAINT sales_subtotal_range CHECK (((subtotal >= (0)::numeric) AND (subtotal < 'Infinity'::numeric))),
    CONSTRAINT sales_tax_range CHECK (((tax_total >= (0)::numeric) AND (tax_total < 'Infinity'::numeric))),
    CONSTRAINT sales_total_arithmetic CHECK ((total = ((subtotal - discount_total) + tax_total)))
);


--
-- Name: TABLE sales; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.sales IS 'Venta del servicio, distinta del cobro. Al publicar, la aplicacion concilia totales con partidas y protege su historial. Una venta draft permite anticipos. Cancelar conserva el total historico y deja importe exigible cero en la vista de saldo.';


--
-- Name: COLUMN sales.appointment_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.sales.appointment_id IS 'Opcional: permite vender servicios sin cita; maximo una venta por cita';


--
-- Name: COLUMN sales.status; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.sales.status IS 'draft, posted, cancelled';


--
-- Name: sales_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.sales_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: sales_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.sales_id_seq OWNED BY public.sales.id;


--
-- Name: schema_migrations; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.schema_migrations (
    version character varying NOT NULL
);


--
-- Name: service_categories; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.service_categories (
    id bigint NOT NULL,
    name character varying NOT NULL,
    created_at timestamp(6) with time zone NOT NULL,
    updated_at timestamp(6) with time zone NOT NULL,
    CONSTRAINT service_categories_name_present CHECK ((btrim((name)::text) <> ''::text))
);


--
-- Name: service_categories_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.service_categories_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: service_categories_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.service_categories_id_seq OWNED BY public.service_categories.id;


--
-- Name: services; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.services (
    id bigint NOT NULL,
    name text NOT NULL,
    duration_minutes integer NOT NULL,
    price numeric(14,2) NOT NULL,
    active boolean DEFAULT true NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    category_id bigint NOT NULL,
    CONSTRAINT services_duration_positive CHECK ((duration_minutes > 0)),
    CONSTRAINT services_name_present CHECK ((btrim(name) <> ''::text)),
    CONSTRAINT services_price_range CHECK (((price >= (0)::numeric) AND (price < 'Infinity'::numeric)))
);


--
-- Name: TABLE services; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.services IS 'Catalogo de servicios con precio y duracion. Los precios acordados y vendidos se conservan por separado para no modificar el historial.';


--
-- Name: COLUMN services.price; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.services.price IS 'Precio actual antes de impuestos, en la moneda del negocio';


--
-- Name: services_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.services_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: services_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.services_id_seq OWNED BY public.services.id;


--
-- Name: users; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.users (
    id bigint NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    email character varying DEFAULT ''::character varying NOT NULL,
    encrypted_password character varying DEFAULT ''::character varying NOT NULL,
    full_name character varying NOT NULL,
    remember_created_at timestamp(6) without time zone,
    reset_password_sent_at timestamp(6) without time zone,
    reset_password_token character varying,
    role_id bigint NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    active boolean DEFAULT true NOT NULL,
    CONSTRAINT users_email_present CHECK ((((email)::text = btrim((email)::text)) AND ((email)::text <> ''::text))),
    CONSTRAINT users_name_password_present CHECK (((btrim((full_name)::text) <> ''::text) AND (btrim((encrypted_password)::text) <> ''::text)))
);


--
-- Name: COLUMN users.email; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.users.email IS 'Unico ignorando mayusculas mediante indice SQL';


--
-- Name: users_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.users_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: users_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.users_id_seq OWNED BY public.users.id;


--
-- Name: appointment_services id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.appointment_services ALTER COLUMN id SET DEFAULT nextval('public.appointment_services_id_seq'::regclass);


--
-- Name: appointments id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.appointments ALTER COLUMN id SET DEFAULT nextval('public.appointments_id_seq'::regclass);


--
-- Name: clients id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.clients ALTER COLUMN id SET DEFAULT nextval('public.clients_id_seq'::regclass);


--
-- Name: employee_services id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.employee_services ALTER COLUMN id SET DEFAULT nextval('public.employee_services_id_seq'::regclass);


--
-- Name: employee_time_off id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.employee_time_off ALTER COLUMN id SET DEFAULT nextval('public.employee_time_off_id_seq'::regclass);


--
-- Name: employee_working_hours id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.employee_working_hours ALTER COLUMN id SET DEFAULT nextval('public.employee_working_hours_id_seq'::regclass);


--
-- Name: employees id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.employees ALTER COLUMN id SET DEFAULT nextval('public.employees_id_seq'::regclass);


--
-- Name: payment_attempts id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.payment_attempts ALTER COLUMN id SET DEFAULT nextval('public.payment_attempts_id_seq'::regclass);


--
-- Name: payments id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.payments ALTER COLUMN id SET DEFAULT nextval('public.payments_id_seq'::regclass);


--
-- Name: roles id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.roles ALTER COLUMN id SET DEFAULT nextval('public.roles_id_seq'::regclass);


--
-- Name: sale_items id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sale_items ALTER COLUMN id SET DEFAULT nextval('public.sale_items_id_seq'::regclass);


--
-- Name: sales id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sales ALTER COLUMN id SET DEFAULT nextval('public.sales_id_seq'::regclass);


--
-- Name: service_categories id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.service_categories ALTER COLUMN id SET DEFAULT nextval('public.service_categories_id_seq'::regclass);


--
-- Name: services id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.services ALTER COLUMN id SET DEFAULT nextval('public.services_id_seq'::regclass);


--
-- Name: users id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.users ALTER COLUMN id SET DEFAULT nextval('public.users_id_seq'::regclass);


--
-- Name: appointment_services appointment_services_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.appointment_services
    ADD CONSTRAINT appointment_services_pkey PRIMARY KEY (id);


--
-- Name: appointments appointments_employee_no_overlap; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.appointments
    ADD CONSTRAINT appointments_employee_no_overlap EXCLUDE USING gist (employee_id WITH =, tstzrange(starts_at, ends_at, '[)'::text) WITH &&) WHERE ((status = ANY (ARRAY['scheduled'::text, 'completed'::text])));


--
-- Name: appointments appointments_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.appointments
    ADD CONSTRAINT appointments_pkey PRIMARY KEY (id);


--
-- Name: ar_internal_metadata ar_internal_metadata_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ar_internal_metadata
    ADD CONSTRAINT ar_internal_metadata_pkey PRIMARY KEY (key);


--
-- Name: business_settings business_settings_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.business_settings
    ADD CONSTRAINT business_settings_pkey PRIMARY KEY (id);


--
-- Name: clients clients_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.clients
    ADD CONSTRAINT clients_pkey PRIMARY KEY (id);


--
-- Name: employee_services employee_services_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.employee_services
    ADD CONSTRAINT employee_services_pkey PRIMARY KEY (id);


--
-- Name: employee_time_off employee_time_off_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.employee_time_off
    ADD CONSTRAINT employee_time_off_pkey PRIMARY KEY (id);


--
-- Name: employee_working_hours employee_working_hours_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.employee_working_hours
    ADD CONSTRAINT employee_working_hours_pkey PRIMARY KEY (id);


--
-- Name: employees employees_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.employees
    ADD CONSTRAINT employees_pkey PRIMARY KEY (id);


--
-- Name: payment_attempts payment_attempts_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.payment_attempts
    ADD CONSTRAINT payment_attempts_pkey PRIMARY KEY (id);


--
-- Name: payments payments_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.payments
    ADD CONSTRAINT payments_pkey PRIMARY KEY (id);


--
-- Name: roles roles_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.roles
    ADD CONSTRAINT roles_pkey PRIMARY KEY (id);


--
-- Name: sale_items sale_items_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sale_items
    ADD CONSTRAINT sale_items_pkey PRIMARY KEY (id);


--
-- Name: sales sales_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sales
    ADD CONSTRAINT sales_pkey PRIMARY KEY (id);


--
-- Name: schema_migrations schema_migrations_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.schema_migrations
    ADD CONSTRAINT schema_migrations_pkey PRIMARY KEY (version);


--
-- Name: service_categories service_categories_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.service_categories
    ADD CONSTRAINT service_categories_pkey PRIMARY KEY (id);


--
-- Name: services services_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.services
    ADD CONSTRAINT services_pkey PRIMARY KEY (id);


--
-- Name: users users_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_pkey PRIMARY KEY (id);


--
-- Name: employee_working_hours working_hours_no_overlap; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.employee_working_hours
    ADD CONSTRAINT working_hours_no_overlap EXCLUDE USING gist (employee_id WITH =, weekday WITH =, numrange(EXTRACT(epoch FROM starts_at), EXTRACT(epoch FROM ends_at), '[)'::text) WITH &&);


--
-- Name: idx_on_employee_id_weekday_starts_at_223771609a; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_on_employee_id_weekday_starts_at_223771609a ON public.employee_working_hours USING btree (employee_id, weekday, starts_at);


--
-- Name: index_appointment_services_on_appointment_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_appointment_services_on_appointment_id ON public.appointment_services USING btree (appointment_id);


--
-- Name: index_appointment_services_on_appointment_id_and_position; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_appointment_services_on_appointment_id_and_position ON public.appointment_services USING btree (appointment_id, "position");


--
-- Name: index_appointment_services_on_service_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_appointment_services_on_service_id ON public.appointment_services USING btree (service_id);


--
-- Name: index_appointments_on_client_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_appointments_on_client_id ON public.appointments USING btree (client_id);


--
-- Name: index_appointments_on_client_id_and_starts_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_appointments_on_client_id_and_starts_at ON public.appointments USING btree (client_id, starts_at);


--
-- Name: index_appointments_on_created_by_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_appointments_on_created_by_id ON public.appointments USING btree (created_by_id);


--
-- Name: index_appointments_on_employee_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_appointments_on_employee_id ON public.appointments USING btree (employee_id);


--
-- Name: index_appointments_on_employee_id_and_starts_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_appointments_on_employee_id_and_starts_at ON public.appointments USING btree (employee_id, starts_at);


--
-- Name: index_appointments_on_id_and_client_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_appointments_on_id_and_client_id ON public.appointments USING btree (id, client_id);


--
-- Name: index_appointments_on_id_and_client_id_and_currency; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_appointments_on_id_and_client_id_and_currency ON public.appointments USING btree (id, client_id, currency);


--
-- Name: index_appointments_on_starts_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_appointments_on_starts_at ON public.appointments USING btree (starts_at);


--
-- Name: index_clients_on_phone; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_clients_on_phone ON public.clients USING btree (phone);


--
-- Name: index_employee_services_on_employee_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_employee_services_on_employee_id ON public.employee_services USING btree (employee_id);


--
-- Name: index_employee_services_on_employee_id_and_service_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_employee_services_on_employee_id_and_service_id ON public.employee_services USING btree (employee_id, service_id);


--
-- Name: index_employee_services_on_service_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_employee_services_on_service_id ON public.employee_services USING btree (service_id);


--
-- Name: index_employee_time_off_on_created_by_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_employee_time_off_on_created_by_id ON public.employee_time_off USING btree (created_by_id);


--
-- Name: index_employee_time_off_on_employee_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_employee_time_off_on_employee_id ON public.employee_time_off USING btree (employee_id);


--
-- Name: index_employee_time_off_on_employee_id_and_starts_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_employee_time_off_on_employee_id_and_starts_at ON public.employee_time_off USING btree (employee_id, starts_at);


--
-- Name: index_employee_working_hours_on_employee_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_employee_working_hours_on_employee_id ON public.employee_working_hours USING btree (employee_id);


--
-- Name: index_employees_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_employees_on_user_id ON public.employees USING btree (user_id);


--
-- Name: index_payment_attempts_on_idempotency_key; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_payment_attempts_on_idempotency_key ON public.payment_attempts USING btree (idempotency_key);


--
-- Name: index_payment_attempts_on_registered_by_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_payment_attempts_on_registered_by_id ON public.payment_attempts USING btree (registered_by_id);


--
-- Name: index_payment_attempts_on_sale_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_payment_attempts_on_sale_id ON public.payment_attempts USING btree (sale_id);


--
-- Name: index_payments_on_id_and_sale_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_payments_on_id_and_sale_id ON public.payments USING btree (id, sale_id);


--
-- Name: index_payments_on_idempotency_key; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_payments_on_idempotency_key ON public.payments USING btree (idempotency_key);


--
-- Name: index_payments_on_original_payment_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_payments_on_original_payment_id ON public.payments USING btree (original_payment_id);


--
-- Name: index_payments_on_registered_by_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_payments_on_registered_by_id ON public.payments USING btree (registered_by_id);


--
-- Name: index_payments_on_sale_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_payments_on_sale_id ON public.payments USING btree (sale_id);


--
-- Name: index_payments_on_sale_id_and_occurred_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_payments_on_sale_id_and_occurred_at ON public.payments USING btree (sale_id, occurred_at);


--
-- Name: index_roles_on_code; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_roles_on_code ON public.roles USING btree (code);


--
-- Name: index_sale_items_on_appointment_service_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_sale_items_on_appointment_service_id ON public.sale_items USING btree (appointment_service_id);


--
-- Name: index_sale_items_on_employee_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_sale_items_on_employee_id ON public.sale_items USING btree (employee_id);


--
-- Name: index_sale_items_on_sale_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_sale_items_on_sale_id ON public.sale_items USING btree (sale_id);


--
-- Name: index_sale_items_on_service_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_sale_items_on_service_id ON public.sale_items USING btree (service_id);


--
-- Name: index_sales_on_appointment_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_sales_on_appointment_id ON public.sales USING btree (appointment_id);


--
-- Name: index_sales_on_checkout_key; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_sales_on_checkout_key ON public.sales USING btree (checkout_key);


--
-- Name: index_sales_on_client_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_sales_on_client_id ON public.sales USING btree (client_id);


--
-- Name: index_sales_on_client_id_and_created_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_sales_on_client_id_and_created_at ON public.sales USING btree (client_id, created_at);


--
-- Name: index_sales_on_created_by_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_sales_on_created_by_id ON public.sales USING btree (created_by_id);


--
-- Name: index_services_on_category_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_services_on_category_id ON public.services USING btree (category_id);


--
-- Name: index_users_on_reset_password_token; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_users_on_reset_password_token ON public.users USING btree (reset_password_token);


--
-- Name: index_users_on_role_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_users_on_role_id ON public.users USING btree (role_id);


--
-- Name: pending_payment_attempts_by_sale; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX pending_payment_attempts_by_sale ON public.payment_attempts USING btree (sale_id) WHERE (status = 'pending'::text);


--
-- Name: service_categories_name_unique; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX service_categories_name_unique ON public.service_categories USING btree (lower((name)::text));


--
-- Name: users_email_lower_unique; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX users_email_lower_unique ON public.users USING btree (lower((email)::text));


--
-- Name: sale_balances _RETURN; Type: RULE; Schema: public; Owner: -
--

CREATE OR REPLACE VIEW public.sale_balances AS
 SELECT s.id AS sale_id,
    s.currency,
    s.status,
    s.total AS original_total,
        CASE
            WHEN (s.status = 'cancelled'::text) THEN (0)::numeric
            ELSE s.total
        END AS amount_due,
    COALESCE(sum(p.amount) FILTER (WHERE (p.kind = 'receipt'::text)), (0)::numeric) AS received,
    COALESCE(sum(p.amount) FILTER (WHERE (p.kind = 'refund'::text)), (0)::numeric) AS refunded,
    ((
        CASE
            WHEN (s.status = 'cancelled'::text) THEN (0)::numeric
            ELSE s.total
        END - COALESCE(sum(p.amount) FILTER (WHERE (p.kind = 'receipt'::text)), (0)::numeric)) + COALESCE(sum(p.amount) FILTER (WHERE (p.kind = 'refund'::text)), (0)::numeric)) AS balance
   FROM (public.sales s
     LEFT JOIN public.payments p ON ((p.sale_id = s.id)))
  GROUP BY s.id;


--
-- Name: payments fk_payments_original_same_sale; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.payments
    ADD CONSTRAINT fk_payments_original_same_sale FOREIGN KEY (original_payment_id, sale_id) REFERENCES public.payments(id, sale_id) DEFERRABLE;


--
-- Name: employee_services fk_rails_0498cac763; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.employee_services
    ADD CONSTRAINT fk_rails_0498cac763 FOREIGN KEY (service_id) REFERENCES public.services(id) DEFERRABLE;


--
-- Name: sale_items fk_rails_0a13c028cc; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sale_items
    ADD CONSTRAINT fk_rails_0a13c028cc FOREIGN KEY (employee_id) REFERENCES public.employees(id) DEFERRABLE;


--
-- Name: sales fk_rails_1f545c13bf; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sales
    ADD CONSTRAINT fk_rails_1f545c13bf FOREIGN KEY (created_by_id) REFERENCES public.users(id) DEFERRABLE;


--
-- Name: users fk_rails_3bb727882f; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT fk_rails_3bb727882f FOREIGN KEY (role_id) REFERENCES public.roles(id);


--
-- Name: payment_attempts fk_rails_3d5716acec; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.payment_attempts
    ADD CONSTRAINT fk_rails_3d5716acec FOREIGN KEY (registered_by_id) REFERENCES public.users(id);


--
-- Name: payment_attempts fk_rails_3e50995dec; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.payment_attempts
    ADD CONSTRAINT fk_rails_3e50995dec FOREIGN KEY (sale_id) REFERENCES public.sales(id);


--
-- Name: sales fk_rails_3fb137af04; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sales
    ADD CONSTRAINT fk_rails_3fb137af04 FOREIGN KEY (client_id) REFERENCES public.clients(id) DEFERRABLE;


--
-- Name: services fk_rails_5a36fd9326; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.services
    ADD CONSTRAINT fk_rails_5a36fd9326 FOREIGN KEY (category_id) REFERENCES public.service_categories(id);


--
-- Name: employee_working_hours fk_rails_5b146be512; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.employee_working_hours
    ADD CONSTRAINT fk_rails_5b146be512 FOREIGN KEY (employee_id) REFERENCES public.employees(id) DEFERRABLE;


--
-- Name: appointment_services fk_rails_5d69e49bb8; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.appointment_services
    ADD CONSTRAINT fk_rails_5d69e49bb8 FOREIGN KEY (appointment_id) REFERENCES public.appointments(id) DEFERRABLE;


--
-- Name: appointments fk_rails_6497fe64e8; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.appointments
    ADD CONSTRAINT fk_rails_6497fe64e8 FOREIGN KEY (client_id) REFERENCES public.clients(id) DEFERRABLE;


--
-- Name: employee_time_off fk_rails_807f00285e; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.employee_time_off
    ADD CONSTRAINT fk_rails_807f00285e FOREIGN KEY (employee_id) REFERENCES public.employees(id) DEFERRABLE;


--
-- Name: appointment_services fk_rails_8e1f6cde5a; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.appointment_services
    ADD CONSTRAINT fk_rails_8e1f6cde5a FOREIGN KEY (service_id) REFERENCES public.services(id) DEFERRABLE;


--
-- Name: payments fk_rails_97b350b093; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.payments
    ADD CONSTRAINT fk_rails_97b350b093 FOREIGN KEY (registered_by_id) REFERENCES public.users(id) DEFERRABLE;


--
-- Name: sale_items fk_rails_a2563c1567; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sale_items
    ADD CONSTRAINT fk_rails_a2563c1567 FOREIGN KEY (sale_id) REFERENCES public.sales(id) DEFERRABLE;


--
-- Name: payments fk_rails_b09036db54; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.payments
    ADD CONSTRAINT fk_rails_b09036db54 FOREIGN KEY (sale_id) REFERENCES public.sales(id) DEFERRABLE;


--
-- Name: sale_items fk_rails_b4067c3b7a; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sale_items
    ADD CONSTRAINT fk_rails_b4067c3b7a FOREIGN KEY (service_id) REFERENCES public.services(id) DEFERRABLE;


--
-- Name: appointments fk_rails_b5e2d3777c; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.appointments
    ADD CONSTRAINT fk_rails_b5e2d3777c FOREIGN KEY (employee_id) REFERENCES public.employees(id) DEFERRABLE;


--
-- Name: sale_items fk_rails_bd7f2d807e; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sale_items
    ADD CONSTRAINT fk_rails_bd7f2d807e FOREIGN KEY (appointment_service_id) REFERENCES public.appointment_services(id) DEFERRABLE;


--
-- Name: appointments fk_rails_dc29d99253; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.appointments
    ADD CONSTRAINT fk_rails_dc29d99253 FOREIGN KEY (created_by_id) REFERENCES public.users(id) DEFERRABLE;


--
-- Name: employees fk_rails_dcfd3d4fc3; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.employees
    ADD CONSTRAINT fk_rails_dcfd3d4fc3 FOREIGN KEY (user_id) REFERENCES public.users(id) DEFERRABLE;


--
-- Name: employee_time_off fk_rails_ddf50e6f34; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.employee_time_off
    ADD CONSTRAINT fk_rails_ddf50e6f34 FOREIGN KEY (created_by_id) REFERENCES public.users(id) DEFERRABLE;


--
-- Name: employee_services fk_rails_f435730b7d; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.employee_services
    ADD CONSTRAINT fk_rails_f435730b7d FOREIGN KEY (employee_id) REFERENCES public.employees(id) DEFERRABLE;


--
-- Name: sales fk_sales_appointment_client; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sales
    ADD CONSTRAINT fk_sales_appointment_client FOREIGN KEY (appointment_id, client_id) REFERENCES public.appointments(id, client_id) DEFERRABLE;


--
-- PostgreSQL database dump complete
--

SET search_path TO "$user", public;

INSERT INTO "schema_migrations" (version) VALUES
('20260906130000'),
('20260906120000'),
('20260905120500'),
('20260905120400'),
('20260905120300'),
('20260905120200'),
('20260905120100'),
('20260905120000'),
('20240510011134'),
('20240510011039'),
('20240510010439'),
('20240425000320');

