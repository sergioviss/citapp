# Citapp

Sistema de citas, servicios, ventas y cobros con una base PostgreSQL por empresa.
Requiere Ruby 4.0.6 y PostgreSQL con `btree_gist`.

La guía de [configuración y operación local](docs/database-operations.md) describe
las variables de entorno, inicialización, pantallas, API, pruebas y recuperación
de cobros externos pendientes.

Después de crear `.env.local` con `DB_PASSWORD`, ejecutar `bin/rails db:prepare`, inicia
`bin/rails server` y entra en `/operations` con una cuenta autorizada.

El sidebar incluye Agenda, Ventas, Clientes, Servicios, Empleados y Configuración
según los permisos. Los listados reutilizan el diseño y controles de la tabla de
usuarios. La agenda abre en día, con una columna por empleado; los descansos,
ausencias y horas fuera de jornada se sombrean automáticamente.

En Ventas → Nueva venta se buscan servicios y clientes por nombre o teléfono.
La opción Cliente nuevo registra al cliente junto con la venta en una sola
transacción. El resumen y el botón Guardar están a la derecha en escritorio;
en móvil se colocan debajo de las partidas. Las ventas se guardan como borrador
y desde su detalle pueden publicarse y recibir cobros.
