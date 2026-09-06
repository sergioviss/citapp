# frozen_string_literal: true

class SaleBalance < ApplicationRecord
  self.primary_key = :sale_id
  self.table_name = "sale_balances"

  belongs_to :sale, inverse_of: :sale_balance

  def readonly?
    true
  end
end
