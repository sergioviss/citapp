# frozen_string_literal: true

require "test_helper"

class PostgresConstraintsTest < ActiveSupport::TestCase
  test "email unique index ignores case" do
    error = assert_raises(ActiveRecord::RecordNotUnique) do
      User.insert!({
        full_name: "Dup",
        email: "Admin@example.com",
        encrypted_password: "x",
        role_id: roles(:admin).id,
        active: true,
        created_at: Time.current,
        updated_at: Time.current
      })
    end

    assert_match(/users_email_lower_unique|unique/i, error.message)
  end

  test "adjacent appointments are allowed and overlaps are rejected" do
    service = create_service!(duration_minutes: 60)
    employee = create_employee!(services: [ service ])
    client = create_client!
    first = book_appointment!(
      employee: employee,
      client: client,
      services: [ service ],
      starts_at: local_slot("2026-06-01", 10),
      ends_at: local_slot("2026-06-01", 11)
    )

    second = book_appointment!(
      employee: employee,
      client: client,
      services: [ service ],
      starts_at: local_slot("2026-06-01", 11),
      ends_at: local_slot("2026-06-01", 12)
    )

    assert_equal first.ends_at, second.starts_at

    error = assert_raises(Domain::Conflict) do
      book_appointment!(
        employee: employee,
        client: client,
        services: [ service ],
        starts_at: local_slot("2026-06-01", 10, 30),
        ends_at: local_slot("2026-06-01", 11, 30)
      )
    end
    assert_match(/ocupado/i, error.message)
  end

  test "working hours exclusion rejects overlapping weekly slots" do
    employee = create_employee!(hours: [])

    error = assert_raises(ActiveRecord::StatementInvalid) do
      employee.employee_working_hours.create!(weekday: 1, starts_at: "09:00", ends_at: "13:00")
      employee.employee_working_hours.create!(weekday: 1, starts_at: "12:00", ends_at: "18:00")
    end
    assert_match(/working_hours_no_overlap|exclusion/i, error.message)
  end

  test "sale_balances view matches receipts and refunds" do
    client = create_client!
    service = create_service!(price: 100)
    sale = Sales::SaveDraft.call(
      actor: users(:admin),
      client_id: client.id,
      items: [ { service_id: service.id, unit_price: 100, quantity: 1, tax_rate: 0 } ]
    )
    Sales::Publish.call(actor: users(:admin), sale: sale)
    receipt = Payments::RecordReceipt.call(
      actor: users(:admin),
      sale: sale,
      amount: 100,
      method: "cash",
      tendered_amount: 200,
      idempotency_key: SecureRandom.uuid
    )
    Payments::RecordRefund.call(
      actor: users(:admin),
      sale: sale,
      original_payment: receipt,
      amount: 40,
      method: "cash",
      reason: "Ajuste",
      idempotency_key: SecureRandom.uuid
    )

    balance = SaleBalance.find(sale.id)
    assert_equal BigDecimal("100.00"), balance.original_total
    assert_equal BigDecimal("100.00"), balance.amount_due
    assert_equal BigDecimal("100.00"), balance.received
    assert_equal BigDecimal("40.00"), balance.refunded
    assert_equal BigDecimal("40.00"), balance.balance
  end

  test "cancelled sale has zero amount due in the view" do
    client = create_client!
    service = create_service!(price: 80)
    sale = Sales::SaveDraft.call(
      actor: users(:admin),
      client_id: client.id,
      items: [ { service_id: service.id, unit_price: 80, quantity: 1, tax_rate: 0 } ]
    )
    Sales::Publish.call(actor: users(:admin), sale: sale)
    Payments::RecordReceipt.call(
      actor: users(:admin),
      sale: sale,
      amount: 80,
      method: "card",
      idempotency_key: SecureRandom.uuid
    )
    Sales::Cancel.call(actor: users(:admin), sale: sale)

    balance = SaleBalance.find(sale.id)
    assert_equal BigDecimal("80.00"), balance.original_total
    assert_equal BigDecimal("0.00"), balance.amount_due
    assert_equal BigDecimal("80.00"), balance.received
    assert_equal BigDecimal("-80.00"), balance.balance
  end

  test "sale linked to appointment must keep the same client and currency" do
    service = create_service!
    employee = create_employee!(services: [ service ])
    client = create_client!
    other = create_client!(name: "Otro")
    appointment = book_appointment!(employee: employee, client: client, services: [ service ], starts_at: local_slot("2026-06-02", 10))

    error = assert_raises(ActiveRecord::InvalidForeignKey) do
      Sale.insert!({
        appointment_id: appointment.id,
        client_id: other.id,
        created_by_id: users(:admin).id,
        currency: "MXN",
        status: "draft",
        subtotal: 0,
        discount_total: 0,
        tax_total: 0,
        total: 0,
        created_at: Time.current,
        updated_at: Time.current
      })
    end
    assert_match(/fk_sales_appointment_client_currency|foreign key/i, error.message)
  end
end
