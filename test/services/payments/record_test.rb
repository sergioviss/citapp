# frozen_string_literal: true

require "test_helper"

class Payments::RecordTest < ActiveSupport::TestCase
  setup do
    @client = create_client!
    @service = create_service!(price: 100)
    @sale = Sales::SaveDraft.call(
      actor: users(:admin),
      client_id: @client.id,
      items: [ { service_id: @service.id, unit_price: 100, quantity: 1, tax_rate: 0 } ]
    )
    Sales::Publish.call(actor: users(:admin), sale: @sale)
  end

  test "records a cash receipt with change" do
    payment = Payments::RecordReceipt.call(
      actor: users(:admin),
      sale: @sale,
      amount: 100,
      method: "cash",
      tendered_amount: 200,
      idempotency_key: SecureRandom.uuid
    )

    assert payment.receipt?
    assert_equal BigDecimal("100.00"), payment.change_amount
    assert_equal 0, @sale.reload.computed_balance
  end

  test "rejects overcharge" do
    error = assert_raises(Domain::ValidationError) do
      Payments::RecordReceipt.call(
        actor: users(:admin),
        sale: @sale,
        amount: 120,
        method: "card",
        idempotency_key: SecureRandom.uuid
      )
    end
    assert_match(/supera el saldo/i, error.message)
  end

  test "idempotent receipt returns the same row" do
    key = SecureRandom.uuid
    first = Payments::RecordReceipt.call(actor: users(:admin), sale: @sale, amount: 40, method: "card", idempotency_key: key)
    second = Payments::RecordReceipt.call(actor: users(:admin), sale: @sale, amount: 40, method: "card", idempotency_key: key)

    assert_equal first.id, second.id
    assert_equal 1, @sale.payments.receipt.count
  end

  test "rejects reused idempotency key with different data" do
    key = SecureRandom.uuid
    Payments::RecordReceipt.call(actor: users(:admin), sale: @sale, amount: 40, method: "card", idempotency_key: key)

    assert_raises(Domain::IdempotencyConflict) do
      Payments::RecordReceipt.call(actor: users(:admin), sale: @sale, amount: 50, method: "card", idempotency_key: key)
    end
  end

  test "rejects refunds larger than the original receipt" do
    receipt = Payments::RecordReceipt.call(actor: users(:admin), sale: @sale, amount: 30, method: "card", idempotency_key: SecureRandom.uuid)

    error = assert_raises(Domain::ValidationError) do
      Payments::RecordRefund.call(
        actor: users(:admin),
        sale: @sale,
        original_payment: receipt,
        amount: 31,
        method: "card",
        reason: "Error",
        idempotency_key: SecureRandom.uuid
      )
    end
    assert_match(/supera el cobro original/i, error.message)
  end

  test "rejects invalid precision and normalizes uppercase retry keys" do
    assert_raises(Domain::ValidationError) do
      Payments::RecordReceipt.call(actor: users(:admin), sale: @sale, amount: "0.001",
        method: "card", idempotency_key: SecureRandom.uuid)
    end
    key = SecureRandom.uuid
    first = Payments::RecordReceipt.call(actor: users(:admin), sale: @sale, amount: 100,
      method: "card", tendered_amount: 150, idempotency_key: key.upcase)
    second = Payments::RecordReceipt.call(actor: users(:admin), sale: @sale, amount: 100,
      method: "card", tendered_amount: 150, idempotency_key: key)
    assert_equal first.id, second.id
    assert_nil first.tendered_amount
  end
end
