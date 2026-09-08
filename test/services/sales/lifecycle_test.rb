# frozen_string_literal: true

require "test_helper"

class Sales::LifecycleTest < ActiveSupport::TestCase
  setup do
    @client = create_client!
    @service = create_service!(name: "Corte", price: 100)
  end

  test "publish reconciles totals from line items" do
    sale = Sales::SaveDraft.call(
      actor: users(:admin),
      client_id: @client.id,
      items: [ { service_id: @service.id, quantity: 2, unit_price: 100, discount_amount: 20, tax_rate: "0.16" } ]
    )
    published = Sales::Publish.call(actor: users(:admin), sale: sale)

    assert published.posted?
    assert_equal BigDecimal("200.00"), published.subtotal
    assert_equal BigDecimal("20.00"), published.discount_total
    assert_equal BigDecimal("0.00"), published.tax_total
    assert_equal BigDecimal("180.00"), published.total
  end

  test "posted sales and items are immutable" do
    sale = Sales::SaveDraft.call(
      actor: users(:admin),
      client_id: @client.id,
      items: [ { service_id: @service.id, unit_price: 100, quantity: 1, tax_rate: 0 } ]
    )
    published = Sales::Publish.call(actor: users(:admin), sale: sale)

    assert_not published.update(notes: "cambio")
    assert_not published.sale_items.first.update(description: "otra")
    assert_not published.destroy
  end

  test "admin destroy removes items payments and attempts" do
    sale = Sales::SaveDraft.call(
      actor: users(:admin),
      client_id: @client.id,
      items: [ { service_id: @service.id, unit_price: 100, quantity: 1, tax_rate: 0 } ]
    )
    receipt = Payments::RecordReceipt.call(actor: users(:admin), sale: sale, amount: 40, method: "cash",
      tendered_amount: 40, idempotency_key: SecureRandom.uuid)
    Payments::RecordRefund.call(actor: users(:admin), sale: sale, original_payment: receipt,
      amount: 40, method: "cash", reason: "Corrección", idempotency_key: SecureRandom.uuid)
    Sales::Publish.call(actor: users(:admin), sale: sale)

    Sales::Destroy.call(actor: users(:admin), sale: sale)

    assert_not Sale.exists?(sale.id)
    assert_empty SaleItem.where(sale_id: sale.id)
    assert_empty Payment.where(sale_id: sale.id)
    assert_empty PaymentAttempt.where(sale_id: sale.id)
  end

  test "receptionist cannot destroy a sale" do
    sale = Sales::SaveDraft.call(
      actor: users(:admin),
      client_id: @client.id,
      items: [ { service_id: @service.id, unit_price: 100, quantity: 1, tax_rate: 0 } ]
    )

    assert_raises(Domain::Forbidden) { Sales::Destroy.call(actor: users(:receptionist), sale: sale) }
    assert Sale.exists?(sale.id)
  end

  test "cancel keeps historical totals" do
    sale = Sales::SaveDraft.call(
      actor: users(:admin),
      client_id: @client.id,
      items: [ { service_id: @service.id, unit_price: 80, quantity: 1, tax_rate: 0 } ]
    )
    Sales::Publish.call(actor: users(:admin), sale: sale)
    cancelled = Sales::Cancel.call(actor: users(:admin), sale: sale)

    assert cancelled.cancelled?
    assert_equal BigDecimal("80.00"), cancelled.total
    assert_equal 0, cancelled.amount_due
  end

  test "links sale items to appointment services of the same appointment" do
    employee = create_employee!(services: [ @service ])
    appointment = book_appointment!(employee: employee, client: @client, services: [ @service ], starts_at: local_slot("2026-06-03", 10))
    line = appointment.appointment_services.first

    sale = Sales::SaveDraft.call(
      actor: users(:admin),
      client_id: @client.id,
      appointment_id: appointment.id,
      items: [ { service_id: @service.id, appointment_service_id: line.id, quantity: 1, tax_rate: 0 } ]
    )

    assert_equal appointment.id, sale.appointment_id
    assert_equal line.id, sale.sale_items.first.appointment_service_id
    assert_equal line.quoted_price, sale.sale_items.first.unit_price
  end

  test "rejects appointment services that do not belong to the sale appointment" do
    employee = create_employee!(services: [ @service ])
    first = book_appointment!(employee: employee, client: @client, services: [ @service ], starts_at: local_slot("2026-06-03", 10))
    second = book_appointment!(employee: employee, client: @client, services: [ @service ], starts_at: local_slot("2026-06-03", 11))
    foreign_line = second.appointment_services.first

    error = assert_raises(ActiveRecord::RecordInvalid) do
      Sales::SaveDraft.call(
        actor: users(:admin),
        client_id: @client.id,
        appointment_id: first.id,
        items: [ { service_id: @service.id, appointment_service_id: foreign_line.id, quantity: 1, tax_rate: 0 } ]
      )
    end
    assert_match(/cita/i, error.message)
  end
end
