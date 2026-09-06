# frozen_string_literal: true

class CreateAvailabilityAndAppointments < ActiveRecord::Migration[8.1]
  def change
    enable_extension "btree_gist"

    create_table :employee_working_hours, comment: "Horario semanal actual en la zona del negocio. Varios tramos por dia permiten descansos. Turnos nocturnos se dividen por dia; 24:00 representa fin de dia." do |t|
      t.references :employee, null: false, foreign_key: { deferrable: :immediate }
      t.integer :weekday, limit: 2, null: false, comment: "ISO: 1=lunes, 7=domingo"
      t.time :starts_at, null: false
      t.time :ends_at, null: false
    end
    add_check_constraint :employee_working_hours, "weekday BETWEEN 1 AND 7", name: "working_hours_weekday_iso"
    add_check_constraint :employee_working_hours, "ends_at > starts_at", name: "working_hours_positive_span"
    add_index :employee_working_hours, [ :employee_id, :weekday, :starts_at ], unique: true

    create_table :employee_time_off, comment: "Ausencias, vacaciones y bloqueos puntuales. La aplicacion debe impedir reservar dentro de estos intervalos y revisar citas al registrar una ausencia." do |t|
      t.references :employee, null: false, foreign_key: { deferrable: :immediate }
      t.timestamptz :starts_at, null: false
      t.timestamptz :ends_at, null: false
      t.text :reason
      t.references :created_by, null: false, foreign_key: { to_table: :users, deferrable: :immediate }
      t.timestamptz :created_at, null: false, default: -> { "now()" }
    end
    add_check_constraint :employee_time_off, "ends_at > starts_at AND isfinite(starts_at) AND isfinite(ends_at)", name: "employee_time_off_finite_span"
    add_index :employee_time_off, [ :employee_id, :starts_at ]

    create_table :appointments, comment: "Reserva individual. Un cliente y un empleado. El SQL agrega exclusion de traslapes por empleado. La aplicacion crea cita y servicios en una transaccion." do |t|
      t.references :client, null: false, foreign_key: { deferrable: :immediate }
      t.references :employee, null: false, foreign_key: { deferrable: :immediate }
      t.references :created_by, null: true, foreign_key: { to_table: :users, deferrable: :immediate }
      t.string :currency, limit: 3, null: false, default: "MXN", comment: "Moneda pactada de los servicios; copiar configuracion al reservar"
      t.timestamptz :starts_at, null: false
      t.timestamptz :ends_at, null: false
      t.text :status, null: false, default: "scheduled"
      t.text :notes
      t.timestamptz :created_at, null: false, default: -> { "now()" }
      t.timestamptz :updated_at, null: false, default: -> { "now()" }
    end
    add_check_constraint :appointments, "status IN ('scheduled', 'completed', 'cancelled', 'no_show')", name: "appointments_status_allowed"
    add_check_constraint :appointments, "ends_at > starts_at AND isfinite(starts_at) AND isfinite(ends_at)", name: "appointments_finite_span"
    add_check_constraint :appointments, "currency ~ '^[A-Z]{3}$'", name: "appointments_currency_format"
    add_index :appointments, [ :employee_id, :starts_at ]
    add_index :appointments, [ :client_id, :starts_at ]
    add_index :appointments, :starts_at
    add_index :appointments, [ :id, :client_id, :currency ], unique: true

    create_table :appointment_services, comment: "Servicios ordenados dentro de la cita. Todos los atiende su mismo empleado. La aplicacion valida al menos uno y que sus duraciones quepan en el intervalo reservado." do |t|
      t.references :appointment, null: false, foreign_key: { deferrable: :immediate }
      t.references :service, null: false, foreign_key: { deferrable: :immediate }
      t.integer :position, null: false
      t.text :service_name, null: false, comment: "Nombre al reservar; conserva el historial"
      t.integer :duration_minutes, null: false, comment: "Duracion acordada para esta reserva"
      t.decimal :quoted_price, precision: 14, scale: 2, null: false, comment: "Precio pactado antes de impuestos en la moneda de la cita"
    end
    add_check_constraint :appointment_services, "position > 0", name: "appointment_services_position_positive"
    add_check_constraint :appointment_services, "btrim(service_name) <> ''", name: "appointment_services_name_present"
    add_check_constraint :appointment_services, "duration_minutes > 0", name: "appointment_services_duration_positive"
    add_check_constraint :appointment_services, "quoted_price >= 0 AND quoted_price < 'Infinity'::numeric", name: "appointment_services_quoted_price_range"
    add_index :appointment_services, [ :appointment_id, :position ], unique: true

    reversible do |dir|
      dir.up do
        execute <<~SQL
          ALTER TABLE employee_working_hours ADD CONSTRAINT working_hours_no_overlap
            EXCLUDE USING gist (
              employee_id WITH =,
              weekday WITH =,
              numrange(extract(epoch FROM starts_at), extract(epoch FROM ends_at), '[)') WITH &&
            )
        SQL
        execute <<~SQL
          ALTER TABLE appointments ADD CONSTRAINT appointments_employee_no_overlap
            EXCLUDE USING gist (
              employee_id WITH =,
              tstzrange(starts_at, ends_at, '[)') WITH &&
            ) WHERE (status IN ('scheduled', 'completed'))
        SQL
      end
      dir.down do
        execute "ALTER TABLE appointments DROP CONSTRAINT IF EXISTS appointments_employee_no_overlap"
        execute "ALTER TABLE employee_working_hours DROP CONSTRAINT IF EXISTS working_hours_no_overlap"
      end
    end
  end
end
