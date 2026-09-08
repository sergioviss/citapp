# frozen_string_literal: true

class CreateBusinessSettingsAndCatalogs < ActiveRecord::Migration[8.1]
  def change
    create_table :business_settings, id: false, comment: "Configuracion de una sola empresa por base de datos. Maximo una fila; crearla al configurar la aplicacion. No es un modelo multiempresa compartido." do |t|
      t.column :id, :smallint, null: false, default: 1
      t.text :name, null: false
      t.text :time_zone, null: false, default: "UTC", comment: "Zona IANA del negocio; configurar antes de reservar"
      t.string :currency, limit: 3, null: false, default: "MXN", comment: "Moneda de operacion. No cambiar sin convertir el catalogo y revisar cotizaciones abiertas"
    end
    execute "ALTER TABLE business_settings ADD PRIMARY KEY (id)"
    add_check_constraint :business_settings, "id = 1", name: "business_settings_singleton"
    add_check_constraint :business_settings, "btrim(name) <> ''", name: "business_settings_name_present"
    add_check_constraint :business_settings, "btrim(time_zone) <> ''", name: "business_settings_time_zone_present"
    add_check_constraint :business_settings, "currency ~ '^[A-Z]{3}$'", name: "business_settings_currency_format"

    create_table :clients, comment: "Persona que reserva. Telefono y email no son unicos: pueden compartirse." do |t|
      t.text :name, null: false
      t.text :phone
      t.text :email
      t.timestamptz :created_at, null: false, default: -> { "now()" }
      t.timestamptz :updated_at, null: false, default: -> { "now()" }
    end
    add_check_constraint :clients, "btrim(name) <> ''", name: "clients_name_present"
    add_index :clients, :phone

    create_table :employees, comment: "Empleado que atiende. Su perfil laboral se separa de la cuenta de acceso opcional. Administradores y recepcionistas pueden tener cuenta sin ser empleados." do |t|
      t.references :user, null: true, foreign_key: { deferrable: :immediate }, index: { unique: true }
      t.text :name, null: false
      t.boolean :active, null: false, default: true
      t.timestamptz :created_at, null: false, default: -> { "now()" }
      t.timestamptz :updated_at, null: false, default: -> { "now()" }
    end
    add_check_constraint :employees, "btrim(name) <> ''", name: "employees_name_present"

    create_table :services, comment: "Catalogo de servicios con precio y duracion. Los precios acordados y vendidos se conservan por separado para no modificar el historial." do |t|
      t.text :name, null: false
      t.integer :duration_minutes, null: false
      t.decimal :price, precision: 14, scale: 2, null: false, comment: "Precio actual antes de impuestos, en la moneda del negocio"
      t.boolean :active, null: false, default: true
      t.timestamptz :created_at, null: false, default: -> { "now()" }
      t.timestamptz :updated_at, null: false, default: -> { "now()" }
    end
    add_check_constraint :services, "btrim(name) <> ''", name: "services_name_present"
    add_check_constraint :services, "duration_minutes > 0", name: "services_duration_positive"
    add_check_constraint :services, "price >= 0 AND price < 'Infinity'::numeric", name: "services_price_range"

    create_table :employee_services, comment: "Servicios que puede realizar cada empleado. La aplicacion verifica esta asignacion al reservar." do |t|
      t.references :employee, null: false, foreign_key: { deferrable: :immediate }
      t.references :service, null: false, foreign_key: { deferrable: :immediate }
    end
    add_index :employee_services, [ :employee_id, :service_id ], unique: true
  end
end
