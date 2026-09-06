# frozen_string_literal: true

class CreateServiceCategories < ActiveRecord::Migration[8.1]
  def up
    create_table :service_categories do |t|
      t.string :name, null: false
      t.timestamps
    end
    add_index :service_categories, "lower(name)", unique: true, name: "service_categories_name_unique"
    add_check_constraint :service_categories, "btrim(name) <> ''", name: "service_categories_name_present"
    execute "INSERT INTO service_categories (name, created_at, updated_at) VALUES ('General', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)"
    add_reference :services, :category, foreign_key: { to_table: :service_categories }
    execute "UPDATE services SET category_id = (SELECT id FROM service_categories WHERE name = 'General')"
    change_column_null :services, :category_id, false
  end

  def down
    remove_reference :services, :category, foreign_key: { to_table: :service_categories }
    drop_table :service_categories
  end
end
