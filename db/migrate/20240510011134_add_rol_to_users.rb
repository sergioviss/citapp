class AddRolToUsers < ActiveRecord::Migration[7.1]
  def change
    add_reference :users, :rol, foreign_key: true
  end
end
