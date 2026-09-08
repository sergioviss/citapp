# frozen_string_literal: true

class AddEmployeeToSaleItems < ActiveRecord::Migration[8.1]
  def change
    add_reference :sale_items, :employee, null: true, foreign_key: { deferrable: :immediate }
  end
end
