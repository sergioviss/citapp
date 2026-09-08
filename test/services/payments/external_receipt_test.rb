# frozen_string_literal: true

require "test_helper"

class Payments::ExternalReceiptTest < ActiveSupport::TestCase
  self.use_transactional_tests = false

  setup do
    @actor = users(:admin)
    @client = create_client!
    @service = create_service!(price: 100)
    @sale = Sales::SaveDraft.call(actor: @actor, client_id: @client.id,
      items: [ { service_id: @service.id, unit_price: 100 } ])
    @key = SecureRandom.uuid
  end

  teardown do
    PaymentAttempt.delete_all
    Payment.delete_all
    SaleItem.delete_all
    Sale.delete_all
    Service.delete_all
    Client.delete_all
  end

  def charge(gateway:, **options)
    Payments::RecordExternalReceipt.call(actor: @actor, sale: @sale, amount: 100,
      method: "card", idempotency_key: @key, gateway: gateway, **options)
  end

  def gateway(&block)
    Object.new.tap { |object| object.define_singleton_method(:charge) { |**args| block.call(**args) } }
  end

  test "rejects cancelled sale before calling gateway" do
    Sales::Cancel.call(actor: @actor, sale: @sale)
    probe = gateway { |**| flunk "Gateway must not be called" }
    assert_raises(Domain::ValidationError) { charge(gateway: probe) }
    assert_equal 0, PaymentAttempt.count
  end

  test "requires an explicitly configured gateway" do
    assert_raises(Domain::ValidationError) { charge(gateway: nil) }
    assert_equal 0, PaymentAttempt.count
  end

  test "reserves before network call and records confirmed payment once" do
    probe = gateway do |**args|
      assert_equal 0, ApplicationRecord.connection.open_transactions
      assert_equal 0, @sale.reload.available_to_collect
      assert_raises(Domain::Conflict) { Sales::Cancel.call(actor: @actor, sale: @sale) }
      assert_raises(Domain::ValidationError) do
        Payments::RecordReceipt.call(actor: @actor, sale: @sale, amount: 1,
          method: "card", idempotency_key: SecureRandom.uuid)
      end
      { success: true, reference: "external-1", amount: args[:amount], currency: args[:currency] }
    end
    first = charge(gateway: probe)
    second = charge(gateway: gateway { |**| flunk "Confirmed retry must not call gateway" })
    assert_equal first.id, second.id
    assert PaymentAttempt.find_by!(idempotency_key: @key).succeeded?
    assert_equal 0, @sale.reload.computed_balance
  end

  test "timeout keeps reservation and same key recovers confirmation" do
    assert_raises(Timeout::Error) { charge(gateway: gateway { |**| raise Timeout::Error }) }
    assert PaymentAttempt.find_by!(idempotency_key: @key).pending?
    assert_equal 0, @sale.reload.available_to_collect
    payment = charge(gateway: gateway { |**| { success: true, reference: "recovered" } })
    assert_equal "recovered", payment.external_reference
    assert_equal 1, @sale.payments.count
  end

  test "explicit decline releases reservation and cannot replay as success" do
    assert_raises(Domain::ValidationError) { charge(gateway: gateway { |**| { success: false } }) }
    assert PaymentAttempt.find_by!(idempotency_key: @key).failed?
    assert_equal 100, @sale.reload.available_to_collect
    assert_raises(Domain::ValidationError) do
      charge(gateway: gateway { |**| flunk "Declined key requires a new attempt" })
    end
  end

  test "invalid confirmation keeps reservation for reconciliation" do
    assert_raises(Domain::Conflict) do
      charge(gateway: gateway { |**| { success: true, reference: "mismatch", amount: 99 } })
    end
    assert PaymentAttempt.find_by!(idempotency_key: @key).pending?
    assert_equal 0, @sale.payments.count
  end

  test "cannot start an external charge inside a transaction" do
    ApplicationRecord.transaction do
      assert_raises(Domain::ValidationError) { charge(gateway: gateway { |**| flunk }) }
    end
  end

  test "concurrent external retries finalize one payment" do
    ready = Queue.new
    release = Queue.new
    probe = gateway do |**|
      ready << true
      release.pop
      { success: true, reference: "same-provider-charge" }
    end
    threads = 2.times.map do
      Thread.new do
        ActiveRecord::Base.connection_pool.with_connection { charge(gateway: probe) }
      end
    end
    Timeout.timeout(10) { 2.times { ready.pop } }
    2.times { release << true }
    results = threads.map { |thread| thread.join(10) || raise("Timeout waiting for payment retry"); thread.value }
    assert_equal results.first.id, results.last.id
    assert_equal 1, @sale.payments.count
    assert_equal 1, @sale.payment_attempts.count
    assert_equal 0, @sale.reload.computed_balance
  ensure
    2.times { release << true } if release
    threads&.each { |thread| thread.join(10) }
  end

  test "pending key cannot be reused for another sale or manual payment" do
    assert_raises(Timeout::Error) { charge(gateway: gateway { |**| raise Timeout::Error }) }
    assert_raises(Domain::IdempotencyConflict) do
      Payments::RecordReceipt.call(actor: @actor, sale: @sale, amount: 100,
        method: "card", idempotency_key: @key)
    end
    other = Sales::SaveDraft.call(actor: @actor, client_id: @client.id,
      items: [ { service_id: @service.id } ])
    assert_raises(Domain::IdempotencyConflict) do
      charge(gateway: gateway { |**| flunk "Conflicting key must not reach provider" }, sale: other)
    end
  end
end
