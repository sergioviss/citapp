# frozen_string_literal: true

require "test_helper"

class SaleItemTest < ActiveSupport::TestCase
  test "applies the documented line arithmetic" do
    client = create_client!
    service = create_service!(price: 100)
    sale = Sale.create!(client: client, created_by: users(:admin), currency: "MXN")
    item = sale.sale_items.create!(
      service: service,
      description: "Corte",
      quantity: 2,
      unit_price: 100,
      discount_amount: 20,
      tax_rate: 0.16
    )

    assert_equal BigDecimal("0"), item.tax_rate
    assert_equal BigDecimal("0.00"), item.tax_amount
    assert_equal BigDecimal("180.00"), item.total
  end
end
