# frozen_string_literal: true

module MoneyMath
  module_function

  def decimal(value)
    BigDecimal(value.to_s)
  end

  def line_amounts(quantity:, unit_price:, discount_amount:, tax_rate:)
    qty = Integer(quantity)
    unit = decimal(unit_price)
    discount = decimal(discount_amount)
    rate = decimal(tax_rate)
    base = (qty * unit) - discount
    tax_amount = (base * rate).round(2)
    total = base + tax_amount

    { base: base, tax_amount: tax_amount, total: total }
  end
end
