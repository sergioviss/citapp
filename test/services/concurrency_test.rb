# frozen_string_literal: true

require "test_helper"

class ConcurrencyTest < ActiveSupport::TestCase
  self.use_transactional_tests = false

  setup do
    @service = create_service!(duration_minutes: 60, price: 100)
    @employee = create_employee!(services: [ @service ])
    @client = create_client!
  end

  teardown do
    PaymentAttempt.delete_all
    Payment.delete_all
    SaleItem.delete_all
    Sale.delete_all
    AppointmentService.delete_all
    Appointment.delete_all
    EmployeeTimeOff.delete_all
    EmployeeWorkingHour.delete_all
    EmployeeService.delete_all
    Employee.delete_all
    Service.delete_all
    Client.delete_all
  end

  test "two overlapping bookings for the same employee, only one succeeds" do
    errors = []
    results = []

    threads = 2.times.map do
      Thread.new do
        ActiveRecord::Base.connection_pool.with_connection do
          results << book_appointment!(
            employee: @employee,
            client: @client,
            services: [ @service ],
            starts_at: local_slot("2026-06-08", 10),
            ends_at: local_slot("2026-06-08", 11)
          )
        rescue Domain::Error => e
          errors << e
        end
      end
    end
    threads.each(&:join)

    assert_equal 1, results.compact.size
    assert_equal 1, errors.size
    assert errors.first.is_a?(Domain::Conflict) || errors.first.is_a?(Domain::ValidationError)
  end

  test "concurrent receipts cannot overcharge a sale" do
    sale = Sales::SaveDraft.call(
      actor: users(:admin),
      client_id: @client.id,
      items: [ { service_id: @service.id, unit_price: 100, quantity: 1, tax_rate: 0 } ]
    )
    Sales::Publish.call(actor: users(:admin), sale: sale)

    errors = []
    results = []
    threads = 2.times.map do
      Thread.new do
        ActiveRecord::Base.connection_pool.with_connection do
          results << Payments::RecordReceipt.call(
            actor: users(:admin),
            sale: sale,
            amount: 100,
            method: "card",
            idempotency_key: SecureRandom.uuid
          )
        rescue Domain::Error => e
          errors << e
        end
      end
    end
    threads.each(&:join)

    assert_equal 1, results.compact.size
    assert_equal 1, errors.size
    assert_match(/saldo/i, errors.first.message)
    assert_equal 0, sale.reload.computed_balance
  end
  test "simultaneous retries return the same receipt" do
    sale = Sales::SaveDraft.call(actor: users(:admin), client_id: @client.id,
      items: [ { service_id: @service.id, unit_price: 100 } ])
    actor = users(:admin)
    key = SecureRandom.uuid
    ready = Queue.new
    release = Queue.new
    threads = 2.times.map do
      Thread.new do
        ActiveRecord::Base.connection_pool.with_connection do
          ready << true
          release.pop
          Payments::RecordReceipt.call(actor: actor, sale: sale, amount: 100,
            method: "card", idempotency_key: key)
        end
      end
    end
    2.times { ready.pop }
    2.times { release << true }
    payments = threads.map(&:value)
    assert_equal payments.first.id, payments.last.id
    assert_equal 1, sale.payments.count
  end

  test "simultaneous refund retries return the same refund" do
    sale = Sales::SaveDraft.call(actor: users(:admin), client_id: @client.id,
      items: [ { service_id: @service.id, unit_price: 100 } ])
    actor = users(:admin)
    receipt = Payments::RecordReceipt.call(actor: actor, sale: sale, amount: 100,
      method: "card", idempotency_key: SecureRandom.uuid)
    key = SecureRandom.uuid
    threads = 2.times.map do
      Thread.new do
        ActiveRecord::Base.connection_pool.with_connection do
          Payments::RecordRefund.call(actor: actor, sale: sale, original_payment: receipt,
            amount: 100, method: "card", reason: "Cancelación", idempotency_key: key)
        end
      end
    end
    refunds = threads.map(&:value)
    assert_equal refunds.first.id, refunds.last.id
    assert_equal 1, receipt.refunds.count
  end
end
