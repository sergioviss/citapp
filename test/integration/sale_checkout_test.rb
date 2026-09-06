require "test_helper"

class SaleCheckoutTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    sign_in users(:receptionist)
    @client = create_client!
    @service = create_service!(price: 200)
    BusinessSetting.current!.update!(usd_exchange_rate: 20)
    @data = { client_id: @client.id, currency: "MXN", discount_percent: 10,
      items: [ { service_id: @service.id } ], checkout_key: SecureRandom.uuid,
      payments: [ { method: "cash", amount: 100 }, { method: "card", amount: 100 } ] }
  end

  test "checkout atomically posts a discounted sale with two payments and cash change" do
    assert_difference "Sale.count" do
      assert_difference "Payment.count", 2 do
        post operations_sales_path, params: { sale: @data }, as: :json
        assert_response :created
      end
    end
    sale = Sale.find(response.parsed_body.fetch("id"))
    assert sale.posted?
    assert_equal users(:receptionist), sale.created_by
    assert_equal 180, sale.total
    assert_equal 20, sale.discount_total
    assert_equal 0, sale.computed_balance
    cash = sale.payments.find_by!(method: "cash")
    assert_equal 80, cash.amount
    assert_equal 20, cash.change_amount
    assert_no_difference [ "Sale.count", "Payment.count" ] do
      post operations_sales_path, params: { sale: @data }, as: :json
      assert_response :created
      assert_equal sale.id, response.parsed_body.fetch("id")
    end
    get operations_sale_path(sale)
    assert_select "form[action=?]", operations_sale_payments_path(sale), count: 0
    assert_select "p", /Cajero:.*#{users(:receptionist).full_name}/
    post refund_operations_sale_payments_path(sale), params: { payment: {
      original_payment_id: cash.id, amount: 20, method: "cash", reason: "Ajuste", idempotency_key: SecureRandom.uuid
    } }, as: :json
    assert_response :created
    assert_no_difference "Payment.count" do
      post operations_sale_payments_path(sale), params: { payment: {
        amount: 20, method: "card", idempotency_key: SecureRandom.uuid
      } }, as: :json
      assert_response :unprocessable_entity
      post external_operations_sale_payments_path(sale), params: { payment: {
        amount: 20, method: "card", idempotency_key: SecureRandom.uuid
      } }, as: :json
      assert_response :unprocessable_entity
    end
  end

  test "invalid payments roll back the client sale and every payment" do
    @data.delete(:client_id)
    @data[:new_client] = { name: "No debe quedar" }
    invalid = [ [], [ { method: "cash", amount: 179 } ],
      [ { method: "card", amount: 200 } ], [ { method: "cash", amount: -1 } ],
      [ { method: "cash", amount: 100 }, { method: "cash", amount: 100 } ],
      [ { method: "cash", amount: 60 }, { method: "card", amount: 60 }, { method: "transfer", amount: 60 } ],
      [ { method: "cash", amount: 180 }, { method: "transfer", amount: 0 } ],
      [ { method: "bogus", amount: 180 } ] ]
    invalid.each do |payments|
      assert_no_difference [ "Client.count", "Sale.count", "SaleItem.count", "Payment.count" ] do
        post operations_sales_path, params: { sale: @data.merge(payments: payments) }, as: :json
        assert_response :unprocessable_entity
      end
    end
  end

  test "USD checkout converts catalog prices and preserves exchange rate history" do
    post operations_sales_path, params: { sale: @data.merge(currency: "USD", payments: [ { method: "transfer", amount: 9 } ]) }, as: :json
    assert_response :created
    sale = Sale.find(response.parsed_body.fetch("id"))
    assert_equal "USD", sale.currency
    assert_equal 10, sale.subtotal
    assert_equal 9, sale.total
    assert_equal 20, sale.exchange_rate
    sign_in users(:admin)
    patch operations_settings_path, params: { business_setting: { usd_exchange_rate: 18 } }, as: :json
    assert_response :success
    assert_equal 20, sale.reload.exchange_rate
    assert_equal 9, sale.total
    [ 0, -1, "NaN" ].each do |rate|
      patch operations_settings_path, params: { business_setting: { usd_exchange_rate: rate } }, as: :json
      assert_response :unprocessable_entity
    end
  end

  test "USD requires configured rate and stale rate requires reviewing the sale" do
    assert_no_difference "Sale.count" do
      post operations_sales_path, params: { sale: @data.merge(exchange_rate: 19) }, as: :json
      assert_response :conflict
      BusinessSetting.current!.update!(usd_exchange_rate: nil)
      post operations_sales_path, params: { sale: @data.merge(currency: "USD") }, as: :json
      assert_response :unprocessable_entity
    end
  end

  test "appointment opens checkout without persisting a sale and can settle in USD" do
    employee = create_employee!(services: [ @service ])
    appointment = book_appointment!(employee: employee, client: @client, services: [ @service ], starts_at: "2026-06-01 10:00")
    assert_no_difference "Sale.count" do
      post from_appointment_operations_sales_path, params: { appointment_id: appointment.id }
      assert_redirected_to new_operations_sale_path(appointment_id: appointment.id)
      follow_redirect!
      assert_response :success
      assert_select "#pos-data", /#{appointment.id}/
    end
    post from_appointment_api_v1_sales_path, params: { appointment_id: appointment.id,
      sale: { currency: "USD", payments: [ { method: "cash", amount: 10 } ] } }, as: :json
    assert_response :created
    assert_equal 10, appointment.reload.sale.total
    assert_equal "USD", appointment.sale.currency
  end

  test "fully discounted sale is saved without a fictitious payment" do
    post operations_sales_path, params: { sale: @data.merge(discount_percent: 100, payments: [ { method: "cash", amount: 0 } ]) }, as: :json
    assert_response :created
    sale = Sale.find(response.parsed_body.fetch("id"))
    assert sale.posted?
    assert_equal 0, sale.total
    assert_empty sale.payments
  end
end
