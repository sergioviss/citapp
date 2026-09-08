# frozen_string_literal: true

class NormalizeRolesAndUsers < ActiveRecord::Migration[8.1]
  def up
    rename_table :rols, :roles
    rename_column :users, :rol_id, :role_id
    rename_index :users, "index_users_on_rol_id", "index_users_on_role_id" if index_exists?(:users, :role_id, name: "index_users_on_rol_id")

    add_column :roles, :code, :text
    add_column :users, :active, :boolean, null: false, default: true

    say_with_time "backfill role codes and require every user to have a role" do
      execute <<~SQL
        UPDATE roles
        SET code = CASE name
          WHEN 'Administrador' THEN 'admin'
          WHEN 'Recepcionista' THEN 'receptionist'
          WHEN 'Empleado' THEN 'employee'
          ELSE regexp_replace(lower(btrim(name)), '[^a-z0-9]+', '_', 'g')
        END
      SQL

      unknown = select_rows(<<~SQL)
        SELECT id, name, code
        FROM roles
        WHERE code IS NULL OR btrim(code) = ''
      SQL
      if unknown.any?
        raise "Hay roles sin código asignable: #{unknown.inspect}. Corrige los nombres antes de migrar."
      end

      duplicates = select_rows(<<~SQL)
        SELECT code, COUNT(*)
        FROM roles
        GROUP BY code
        HAVING COUNT(*) > 1
      SQL
      if duplicates.any?
        raise "Hay códigos de rol duplicados: #{duplicates.inspect}."
      end

      users_without_role = select_value("SELECT COUNT(*) FROM users WHERE role_id IS NULL").to_i
      if users_without_role.positive?
        raise "Hay #{users_without_role} usuario(s) sin rol. Asigna un rol antes de migrar."
      end

      email_collisions = select_rows(<<~SQL)
        SELECT lower(email), COUNT(*)
        FROM users
        GROUP BY lower(email)
        HAVING COUNT(*) > 1
      SQL
      if email_collisions.any?
        raise "Hay correos duplicados ignorando mayúsculas: #{email_collisions.inspect}."
      end

      execute <<~SQL
        UPDATE users
        SET full_name = split_part(email, '@', 1)
        WHERE full_name IS NULL OR btrim(full_name) = ''
      SQL
    end

    change_column_null :roles, :code, false
    change_column_null :roles, :name, false
    change_column_null :users, :role_id, false
    change_column_null :users, :full_name, false

    add_index :roles, :code, unique: true
    add_check_constraint :roles, "btrim(code) <> '' AND btrim(name) <> ''", name: "roles_code_name_present"

    remove_index :users, :email if index_exists?(:users, :email)
    add_index :users, "lower(email)", unique: true, name: "users_email_lower_unique"

    add_check_constraint :users, "btrim(full_name) <> '' AND btrim(encrypted_password) <> ''", name: "users_name_password_present"
    add_check_constraint :users, "email = btrim(email) AND email <> ''", name: "users_email_present"

    change_column_comment :users, :email, "Unico ignorando mayusculas mediante indice SQL"
  end

  def down
    remove_check_constraint :users, name: "users_email_present"
    remove_check_constraint :users, name: "users_name_password_present"
    remove_index :users, name: "users_email_lower_unique"
    add_index :users, :email, unique: true

    remove_check_constraint :roles, name: "roles_code_name_present"
    remove_index :roles, :code

    change_column_null :users, :full_name, true
    change_column_null :users, :role_id, true
    change_column_null :roles, :name, true

    remove_column :users, :active
    remove_column :roles, :code

    rename_column :users, :role_id, :rol_id
    rename_table :roles, :rols
  end
end
