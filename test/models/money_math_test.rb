# frozen_string_literal: true

require "test_helper"

class MoneyMathTest < ActiveSupport::TestCase
  test "computes tax and total with bank rounding to two decimals" do
    amounts = MoneyMath.line_amounts(quantity: 1, unit_price: "100.00", discount_amount: "10.00", tax_rate: "0.16")

    assert_equal BigDecimal("90.00"), amounts[:base]
    assert_equal BigDecimal("14.40"), amounts[:tax_amount]
    assert_equal BigDecimal("104.40"), amounts[:total]
    assert_instance_of BigDecimal, amounts[:total]
  end
end
