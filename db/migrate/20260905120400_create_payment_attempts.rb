# frozen_string_literal: true

class CreatePaymentAttempts < ActiveRecord::Migration[8.1]
  def change
    create_table :payment_attempts do |t|
      t.references :sale, null: false, foreign_key: true
      t.references :registered_by, null: false, foreign_key: { to_table: :users }
      t.uuid :idempotency_key, null: false
      t.decimal :amount, precision: 14, scale: 2, null: false
      t.string :currency, limit: 3, null: false
      t.text :method, null: false
      t.text :status, null: false, default: "pending"
      t.text :external_reference
      t.timestamptz :created_at, null: false, default: -> { "now()" }
      t.timestamptz :updated_at, null: false, default: -> { "now()" }
    end
    add_index :payment_attempts, :idempotency_key, unique: true
    add_index :payment_attempts, :sale_id, where: "status = 'pending'", name: "pending_payment_attempts_by_sale"
    add_check_constraint :payment_attempts, "amount > 0 AND amount < 'Infinity'::numeric", name: "payment_attempts_amount_range"
    add_check_constraint :payment_attempts, "currency ~ '^[A-Z]{3}$'", name: "payment_attempts_currency"
    add_check_constraint :payment_attempts, "method IN ('card', 'transfer')", name: "payment_attempts_method"
    add_check_constraint :payment_attempts, "status IN ('pending', 'succeeded', 'failed')", name: "payment_attempts_status"
  end
end
