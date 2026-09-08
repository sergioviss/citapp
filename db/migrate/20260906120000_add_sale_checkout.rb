class AddSaleCheckout < ActiveRecord::Migration[8.1]
  def change
    add_column :business_settings, :usd_exchange_rate, :decimal, precision: 12, scale: 6
    add_check_constraint :business_settings, "usd_exchange_rate > 0 AND usd_exchange_rate < 'Infinity'::numeric", name: "settings_exchange_rate_positive"
    add_column :sales, :exchange_rate, :decimal, precision: 12, scale: 6
    add_column :sales, :discount_percent, :decimal, precision: 5, scale: 2, null: false, default: 0
    add_column :sales, :checkout_key, :uuid
    add_index :sales, :checkout_key, unique: true
    add_check_constraint :sales, "exchange_rate > 0 AND exchange_rate < 'Infinity'::numeric", name: "sales_exchange_rate_positive"
    add_check_constraint :sales, "discount_percent BETWEEN 0 AND 100", name: "sales_discount_percent_range"
    add_index :appointments, [ :id, :client_id ], unique: true
    reversible do |dir|
      dir.up do
        execute "ALTER TABLE sales DROP CONSTRAINT fk_sales_appointment_client_currency"
        execute "ALTER TABLE sales ADD CONSTRAINT fk_sales_appointment_client FOREIGN KEY (appointment_id, client_id) REFERENCES appointments (id, client_id) DEFERRABLE INITIALLY IMMEDIATE"
      end
      dir.down do
        execute "ALTER TABLE sales DROP CONSTRAINT fk_sales_appointment_client"
        execute "ALTER TABLE sales ADD CONSTRAINT fk_sales_appointment_client_currency FOREIGN KEY (appointment_id, client_id, currency) REFERENCES appointments (id, client_id, currency) DEFERRABLE INITIALLY IMMEDIATE"
      end
    end
  end
end
