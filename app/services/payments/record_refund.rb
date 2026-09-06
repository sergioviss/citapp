# frozen_string_literal: true

module Payments
  class RecordRefund < Operation
    def initialize(actor:, sale:, original_payment:, amount:, method:, idempotency_key:, reason:, occurred_at: nil)
      @actor = actor
      @sale = sale
      @original_payment = original_payment
      @amount = money(amount)
      @method = method.to_s
      @idempotency_key = normalize_key(idempotency_key)
      @reason = reason
      @occurred_at = occurred_at
    end

    def call
      authorize!(actor, :create, Payment)

      with_operation do |record|
        existing = Payment.find_by(idempotency_key: idempotency_key)
        return existing if existing && same_operation?(existing)
        raise Domain::IdempotencyConflict, "La clave de idempotencia ya se usó en otra operación" if existing

        reject_reserved_key!
        source = Payment.lock.find(original_payment.id)

        raise Domain::ValidationError, "La devolución debe referir un cobro de la misma venta" unless source.sale_id == record.id
        raise Domain::ValidationError, "La devolución debe referir un cobro" unless source.receipt?

        remaining = source.amount - source.refunds.sum(:amount)
        if amount > remaining
          raise Domain::ValidationError, "La devolución supera el cobro original"
        end

        Payment.create!(
          sale: record,
          registered_by: actor,
          kind: "refund",
          original_payment: source,
          method: method,
          amount: amount,
          reason: reason,
          idempotency_key: idempotency_key,
          occurred_at: occurred_at || Time.current
        )
      end
    end

    private

    attr_reader :actor, :sale, :original_payment, :amount, :method, :idempotency_key, :reason, :occurred_at

    def same_operation?(payment)
      payment.sale_id == sale.id &&
        payment.refund? &&
        payment.original_payment_id == original_payment.id &&
        payment.method == method &&
        payment.amount == amount
    end
  end
end
