# Operación local y base de datos

La aplicación usa PostgreSQL independiente por empresa. `db/structure.sql` es el
DDL de referencia; las migraciones en `db/migrate` son la fuente de los cambios.
Se usa formato SQL porque hay vistas y restricciones de exclusión GiST.

## Preparar el entorno

Se requieren Ruby 4.0.6, las dependencias de `Gemfile.lock` y PostgreSQL con
`btree_gist` disponible. Selecciona la versión de Ruby antes de ejecutar Bundler
(por ejemplo, `rvm use 4.0.6` si usas RVM).

La conexión acepta `DATABASE_URL` o `DB_HOST`, `DB_PORT`, `DB_USER` y
`DB_PASSWORD`. El archivo `.env.local` está excluido de Git y puede conservar la
configuración personal. Rails lo carga automáticamente en desarrollo y pruebas;
sus valores nunca sustituyen los definidos por el shell:

```sh
bundle install
bin/rails db:prepare
bin/rails server
```

Para cargar ejemplos locales de clientes, servicios, empleados, horarios,
citas y ventas, primero asegúrate de tener una cuenta activa y ejecuta:

```sh
SEED_DEMO_DATA=true bin/rails db:seed
```

Los ejemplos solo se cargan de forma explícita fuera de producción y el comando
es idempotente: volver a ejecutarlo actualiza los mismos registros demo.

Los nombres predeterminados son `citapp_development` y `citapp_test`. Nunca
apuntes el entorno de pruebas a una base con datos de operación.

## Inicialización del negocio y administrador

`bin/rails db:seed` crea los roles y una configuración inicial si no existen.
Para una empresa nueva se pueden definir `BUSINESS_NAME`, `BUSINESS_TIME_ZONE`
y `BUSINESS_CURRENCY`; sus valores predeterminados son `Citapp`,
`America/Hermosillo` y `MXN`. Verifica la zona de cada negocio antes de operar.
El seed conserva los valores de una configuración existente, incluso UTC.

Para crear un administrador nuevo, define `ADMIN_EMAIL` y `ADMIN_PASSWORD` en
el entorno y ejecuta los seeds. `ADMIN_NAME` es opcional. La contraseña nunca se
incluye en el repositorio. Ejecutar nuevamente los seeds no cambia contraseñas,
roles ni el estado de cuentas existentes. Las cuentas creadas con versiones
anteriores conservan sus credenciales; su contraseña se cambia mediante el
flujo normal de administración o recuperación.

La pantalla de configuración permite ajustar zona y moneda antes de cargar
catálogos, horarios u operaciones. Cambiarlas con datos existentes requiere una
conversión planificada, porque los importes e instantes históricos tienen su
propia moneda y significado temporal.

## Pantallas y API

Después de iniciar sesión, entra en `/operations` o usa el enlace «Agenda y
ventas» del encabezado. Las rutas anteriores `/apps/calendar` y
`/apps/invoice/*` redirigen a las pantallas operativas.

1. En el **sidebar**, abre Clientes, Servicios o Empleados para buscar, crear
   y editar registros con las mismas tablas y controles que Usuarios.
2. Abre un empleado, asigna servicios y define su horario. Los días son ISO
   (1=lunes, 7=domingo). Se permiten varios tramos y `24:00` como fin del día.
3. **Agenda** abre en modo día, con una columna por empleado y una escala de
   horas compartida. Selecciona un intervalo libre para reservar; pulsa una
   cita para consultar sus datos, reprogramar o cambiar su estado. Las horas
   fuera de jornada, descansos y ausencias se sombrean automáticamente. Sin
   horario configurado, todo el día aparece no disponible. El servidor valida
   disponibilidad, servicios habilitados y duración; PostgreSQL impide traslapes.
4. Usa **Preparar venta** para conservar los precios reservados, o crea una
   venta sin cita en **Ventas → Nueva venta**. Busca servicios para agregarlos
   a las partidas y clientes por nombre o teléfono, incluso sin espacios ni
   guiones. Si eliges **Cliente nuevo**, se crea junto con la venta; cualquier
   error revierte ambos registros. El resumen, notas y botón Guardar están a
   la derecha en escritorio y debajo de las partidas en móvil.
5. Edita el borrador y publícalo. Registra cobros recibidos, anticipos o
   devoluciones; cada formulario conserva una clave para reintentar el envío.

Las pantallas usan el layout del tema, DataTables y SweetAlert existentes.
La agenda reutiliza FullCalendar `timeGridDay` en columnas sincronizadas,
sin incorporar plugins de recursos comerciales. Los horarios se presentan en
la zona del negocio independientemente de la zona del navegador. El empleado
con rol de atención solo puede consultar su propia columna y las acciones
permitidas. Los datos de disponibilidad se actualizan al abrir o recargar el día.

Las mismas operaciones están disponibles bajo `/api/v1` con JSON. Usan la
sesión de la aplicación y permisos por rol. Las escrituras de sesión conservan
la protección CSRF de Rails: los clientes con cookies deben enviar el token de
`csrf_meta_tags` mediante `X-CSRF-Token`. No se introdujo autenticación por token.

| Operación | Ruta |
|---|---|
| Consultar agenda | `GET /api/v1/appointments?date=2026-09-07` |
| Reservar | `POST /api/v1/appointments` |
| Reprogramar | `PATCH /api/v1/appointments/:id/reschedule` |
| Cambiar estado | `PATCH /api/v1/appointments/:id/change_status` |
| Crear o editar cliente/servicio/empleado | `POST /api/v1/clients`, `services`, `employees`; `PATCH /:id` |
| Asignar servicios | `PUT /api/v1/employees/:id/assign_services` |
| Reemplazar horario completo | `PUT /api/v1/employees/:id/working_hours` |
| Registrar ausencia | `POST /api/v1/employees/:id/time_off` |
| Crear venta desde cita | `POST /api/v1/sales/from_appointment` |
| Consultar, crear o editar venta | `GET/POST /api/v1/sales`, `GET/PATCH /api/v1/sales/:id` |
| Publicar o cancelar | `POST /api/v1/sales/:id/publish`, `/cancel` |
| Registrar dinero ya recibido | `POST /api/v1/sales/:sale_id/payments` |
| Registrar devolución ya realizada | `POST /api/v1/sales/:sale_id/payments/refund` |
| Iniciar o recuperar cobro externo | `POST /api/v1/sales/:sale_id/payments/external` |

Consulta `test/integration/operations_test.rb` para payloads completos. Los
horarios de reserva y ausencia se envían como hora local del negocio,
`YYYY-MM-DDTHH:MM` o `YYYY-MM-DD HH:MM`; las respuestas serializan instantes.
Horas inexistentes o ambiguas por cambio de horario se rechazan.

## Cobros externos y recuperación

Los cobros manuales registran dinero ya confirmado; no llaman a una pasarela.
El endpoint externo está deshabilitado hasta que se configure explícitamente
`Rails.configuration.x.payment_gateway` con un adaptador. `NullGateway` es una
simulación que sólo debe inyectarse en pruebas, nunca se selecciona por defecto.
No se conectó ningún proveedor real ni se realizaron cargos reales.

El adaptador implementa:

```ruby
charge(amount:, currency:, idempotency_key:, method:, metadata:)
# Confirmación: { success: true, reference: "referencia", amount: ..., currency: ... }
# Rechazo definitivo sin cargo: { success: false }
# Resultado incierto: levantar una excepción, por ejemplo Timeout::Error.
```

El proveedor/adaptador debe garantizar que la misma clave reproduce el mismo
resultado sin cobrar dos veces, incluso en solicitudes concurrentes. Un timeout
o error de transporte nunca debe convertirse en `success: false`: ese valor
significa que se sabe que no hubo cargo. Conserva proveedor, parámetros y clave
durante la recuperación de un intento. La referencia es obligatoria para una
confirmación; si se incluyen importe y moneda deben coincidir con lo reservado.

`payment_attempts` conserva la solicitud antes de llamar al proveedor:

- `pending`: el importe está reservado. Impide otros cobros por ese importe y
  bloquea cambios en la venta y sus partidas.
- `succeeded`: el pago confirmado y el resultado se guardaron en una misma
  transacción. Repetir la solicitud devuelve el mismo pago.
- `failed`: rechazo definitivo; libera la reserva y exige otra clave para un
  nuevo intento.

La red se utiliza fuera de toda transacción. Si el proceso cae, hay timeout o
se pierde la confirmación, el intento permanece `pending`. Reenvía el mismo
payload y clave al endpoint externo, o usa «Consultar y completar cobro» en la
venta con el adaptador configurado. No elimines el intento ni registres ese
mismo dinero con otra clave. No hay caducidad automática de reservas porque
liberarlas sin conciliar podría permitir un cobro duplicado.

`sale_balances` sigue mostrando sólo movimientos confirmados. El importe
disponible para nuevos cobros resta también las reservas pendientes.

## Integridad y rendimiento

Las operaciones monetarias bloquean primero la clave de idempotencia y después
la venta. Los bloqueos se liberan al terminar la transacción. Los cambios de
cita comprueban de nuevo estado y permisos después de recargar y bloquear.
Ventas y partidas consultan el estado persistido bajo bloqueo para evitar que
un objeto de borrador antiguo cambie una venta publicada. Cancelar sólo permite
el cambio de estado, conservando importes e identidad históricos.

Estas reglas de varias filas se aplican mediante los servicios y modelos de
Rails. SQL directo, `update_all`, `delete_all` y operaciones que omitan callbacks
requieren el mismo cuidado que cualquier mantenimiento de datos; no son API de
operación. Las restricciones originales de PostgreSQL siguen activas.

La reserva carga servicios y habilitaciones en consultas agrupadas; el saldo
agrupa cobros y devoluciones en una sola consulta. Los índices existentes se
conservan: retirar índices potencialmente redundantes requiere medir consultas
y uso real con `EXPLAIN (ANALYZE, BUFFERS)` y `pg_stat_user_indexes`.

## Verificación local

```sh
RAILS_ENV=test bin/rails db:prepare
PARALLEL_WORKERS=1 bin/rails test
bin/rails zeitwerk:check
bin/rubocop app/controllers/operations app/services test/services test/integration/operations_test.rb
```

Las pruebas de pagos externos usan adaptadores de prueba y una base local. Las
pruebas de concurrencia usan conexiones PostgreSQL independientes. No requieren
credenciales ni servicios de pago externos.

Verificación del 5 de septiembre de 2026:

- 99 pruebas, 347 verificaciones, sin fallos ni errores.
- Carga completa de clases de Rails correcta; estilo de los archivos revisados
  y análisis de seguridad con Brakeman sin advertencias pendientes.
- Instalación desde una base temporal vacía: migraciones, 15 tablas de negocio,
  vista de saldos, exclusiones y seeds verificados. La base temporal se eliminó.
- Navegador local: alta de catálogos y empleado, asignación de servicio, horario
  hasta `24:00`, reserva, venta, publicación, cobro con cambio, cancelación y
  devolución. Saldo final cero y total histórico conservado.
- Migración de intentos de pago aplicada en desarrollo y pruebas locales.
- Ordenamiento del listado de usuarios limitado a columnas configuradas y
  direcciones `asc`/`desc`, con pruebas contra entradas SQL no permitidas.
- Nuevas pantallas verificadas en navegador con una base temporal independiente:
  búsqueda por teléfono, cliente nuevo y venta atómicos, descuentos e impuestos,
  edición de borrador, publicación con SweetAlert, cobro con cambio, búsqueda y
  edición de catálogos, selección de citas y bloqueo de horas no disponibles.
  Tres columnas de empleados y hora local correcta con el navegador en Tokio;
  diseño móvil y modo oscuro revisados, sin errores de JavaScript ni consola.
