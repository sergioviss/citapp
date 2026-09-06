# frozen_string_literal: true

class CreateSalesPaymentsAndBalances < ActiveRecord::Migration[8.1]
  def change
    create_table :sales, comment: "Venta del servicio, distinta del cobro. Al publicar, la aplicacion concilia totales con partidas y protege su historial. Una venta draft permite anticipos. Cancelar conserva el total historico y deja importe exigible cero en la vista de saldo." do |t|
      t.bigint :appointment_id, comment: "Opcional: permite vender servicios sin cita; maximo una venta por cita"
      t.references :client, null: false, foreign_key: { deferrable: :immediate }
      t.references :created_by, null: false, foreign_key: { to_table: :users, deferrable: :immediate }
      t.string :currency, limit: 3, null: false, default: "MXN"
      t.text :status, null: false, default: "draft", comment: "draft, posted, cancelled"
      t.decimal :subtotal, precision: 14, scale: 2, null: false, default: 0
      t.decimal :discount_total, precision: 14, scale: 2, null: false, default: 0
      t.decimal :tax_total, precision: 14, scale: 2, null: false, default: 0
      t.decimal :total, precision: 14, scale: 2, null: false, default: 0
      t.text :notes
      t.timestamptz :created_at, null: false, default: -> { "now()" }
      t.timestamptz :updated_at, null: false, default: -> { "now()" }
    end
    add_index :sales, :appointment_id, unique: true
    add_index :sales, [ :client_id, :created_at ]
    add_check_constraint :sales, "currency ~ '^[A-Z]{3}$'", name: "sales_currency_format"
    add_check_constraint :sales, "status IN ('draft', 'posted', 'cancelled')", name: "sales_status_allowed"
    add_check_constraint :sales, "subtotal >= 0 AND subtotal < 'Infinity'::numeric", name: "sales_subtotal_range"
    add_check_constraint :sales, "discount_total BETWEEN 0 AND subtotal", name: "sales_discount_range"
    add_check_constraint :sales, "tax_total >= 0 AND tax_total < 'Infinity'::numeric", name: "sales_tax_range"
    add_check_constraint :sales, "total = subtotal - discount_total + tax_total", name: "sales_total_arithmetic"

    create_table :sale_items, comment: "Partida historica. La aplicacion verifica que el servicio reservado pertenezca a la cita de esta venta y al mismo servicio. No recalcular con precios actuales del catalogo." do |t|
      t.references :sale, null: false, foreign_key: { deferrable: :immediate }
      t.references :service, null: false, foreign_key: { deferrable: :immediate }
      t.references :appointment_service, null: true, foreign_key: { deferrable: :immediate }, index: { unique: true }
      t.text :description, null: false, comment: "Nombre o descripcion al vender"
      t.integer :quantity, null: false, default: 1
      t.decimal :unit_price, precision: 14, scale: 2, null: false, comment: "Antes de impuestos; moneda de la venta"
      t.decimal :discount_amount, precision: 14, scale: 2, null: false, default: 0, comment: "Descuento total de esta partida"
      t.decimal :tax_rate, precision: 7, scale: 6, null: false, default: 0, comment: "Fraccion: 0.16 = 16 por ciento"
      t.decimal :tax_amount, precision: 14, scale: 2, null: false, default: 0
      t.decimal :total, precision: 14, scale: 2, null: false
    end
    add_check_constraint :sale_items, "btrim(description) <> '' AND quantity > 0", name: "sale_items_description_quantity"
    add_check_constraint :sale_items, "unit_price >= 0 AND unit_price < 'Infinity'::numeric", name: "sale_items_unit_price_range"
    add_check_constraint :sale_items, "discount_amount BETWEEN 0 AND quantity * unit_price", name: "sale_items_discount_range"
    add_check_constraint :sale_items, "tax_rate BETWEEN 0 AND 1", name: "sale_items_tax_rate_range"
    add_check_constraint :sale_items, "tax_amount = round((quantity * unit_price - discount_amount) * tax_rate, 2)", name: "sale_items_tax_arithmetic"
    add_check_constraint :sale_items, "total = quantity * unit_price - discount_amount + tax_amount", name: "sale_items_total_arithmetic"

    create_table :payments, comment: "Solo movimientos confirmados. Multiples filas permiten anticipos, abonos y pagos mixtos. La aplicacion impide sobrecobros, devoluciones excesivas y cambios en movimientos confirmados; implementa permisos e idempotencia." do |t|
      t.references :sale, null: false, foreign_key: { deferrable: :immediate }
      t.references :registered_by, null: false, foreign_key: { to_table: :users, deferrable: :immediate }
      t.text :kind, null: false, default: "receipt", comment: "receipt = cobro; refund = devolucion de dinero"
      t.bigint :original_payment_id, comment: "Obligatorio para refund; referencia un cobro de esta misma venta"
      t.text :method, null: false, comment: "cash, card, transfer"
      t.decimal :amount, precision: 14, scale: 2, null: false, comment: "Neto aplicado o devuelto; siempre positivo; moneda de la venta"
      t.decimal :tendered_amount, precision: 14, scale: 2, comment: "Solo cobro en efectivo. Cambio = tendered_amount - amount"
      t.text :external_reference
      t.text :reason, comment: "Obligatorio para devoluciones"
      t.uuid :idempotency_key, null: false, comment: "Generada por el cliente de la operacion y reutilizada en cada reintento"
      t.timestamptz :occurred_at, null: false, default: -> { "now()" }
    end
    add_index :payments, :idempotency_key, unique: true
    add_index :payments, [ :sale_id, :occurred_at ]
    add_index :payments, [ :id, :sale_id ], unique: true
    add_index :payments, :original_payment_id
    add_check_constraint :payments, "kind IN ('receipt', 'refund')", name: "payments_kind_allowed"
    add_check_constraint :payments, "method IN ('cash', 'card', 'transfer')", name: "payments_method_allowed"
    add_check_constraint :payments, "amount > 0 AND amount < 'Infinity'::numeric", name: "payments_amount_range"
    add_check_constraint :payments, "(kind = 'refund') = (original_payment_id IS NOT NULL)", name: "payments_refund_has_original"
    add_check_constraint :payments, "original_payment_id IS NULL OR original_payment_id <> id", name: "payments_original_not_self"
    add_check_constraint :payments, "kind <> 'refund' OR (reason IS NOT NULL AND btrim(reason) <> '')", name: "payments_refund_reason_present"
    add_check_constraint :payments, <<~SQL.squish, name: "payments_cash_tendered"
      (kind = 'receipt' AND method = 'cash' AND tendered_amount IS NOT NULL AND tendered_amount >= amount AND tendered_amount < 'Infinity'::numeric)
      OR ((kind <> 'receipt' OR method <> 'cash') AND tendered_amount IS NULL)
    SQL

    reversible do |dir|
      dir.up do
        execute <<~SQL
          ALTER TABLE sales
            ADD CONSTRAINT fk_sales_appointment_client_currency
            FOREIGN KEY (appointment_id, client_id, currency)
            REFERENCES appointments (id, client_id, currency)
            DEFERRABLE INITIALLY IMMEDIATE
        SQL
        execute <<~SQL
          ALTER TABLE payments
            ADD CONSTRAINT fk_payments_original_same_sale
            FOREIGN KEY (original_payment_id, sale_id)
            REFERENCES payments (id, sale_id)
            DEFERRABLE INITIALLY IMMEDIATE
        SQL
        execute <<~SQL
          CREATE VIEW sale_balances AS
          SELECT s.id AS sale_id, s.currency, s.status, s.total AS original_total,
                 CASE WHEN s.status = 'cancelled' THEN 0 ELSE s.total END AS amount_due,
                 coalesce(sum(p.amount) FILTER (WHERE p.kind = 'receipt'), 0) AS received,
                 coalesce(sum(p.amount) FILTER (WHERE p.kind = 'refund'), 0) AS refunded,
                 CASE WHEN s.status = 'cancelled' THEN 0 ELSE s.total END
                   - coalesce(sum(p.amount) FILTER (WHERE p.kind = 'receipt'), 0)
                   + coalesce(sum(p.amount) FILTER (WHERE p.kind = 'refund'), 0) AS balance
          FROM sales s LEFT JOIN payments p ON p.sale_id = s.id
          GROUP BY s.id
        SQL
        execute "COMMENT ON VIEW sale_balances IS 'Positivo: por cobrar; negativo: a favor del cliente. Draft es provisional. La vista calcula saldos, no impide sobrecobros ni devoluciones excesivas.'"
      end
      dir.down do
        execute "DROP VIEW IF EXISTS sale_balances"
        execute "ALTER TABLE payments DROP CONSTRAINT IF EXISTS fk_payments_original_same_sale"
        execute "ALTER TABLE sales DROP CONSTRAINT IF EXISTS fk_sales_appointment_client_currency"
      end
    end
  end
end
