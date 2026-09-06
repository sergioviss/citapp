# frozen_string_literal: true

module Payments
  class RecordReceipt < Operation
    def initialize(actor:, sale:, amount:, method:, idempotency_key:, tendered_amount: nil, external_reference: nil, occurred_at: nil)
      @actor = actor
      @sale = sale
      @amount = money(amount)
      @method = method.to_s
      @idempotency_key = normalize_key(idempotency_key)
      @tendered_amount = @method == "cash" && tendered_amount ? money(tendered_amount) : nil
      @external_reference = external_reference
      @occurred_at = occurred_at
    end

    def call
      authorize!(actor, :create, Payment)

      with_operation do |record|
        existing = Payment.find_by(idempotency_key: idempotency_key)
        return existing if existing && same_operation?(existing)
        raise Domain::IdempotencyConflict, "La clave de idempotencia ya se usó en otra operación" if existing

        reject_reserved_key!
        if record.checkout_key.present? && !record.draft?
          raise Domain::ValidationError, "Los cobros se registran únicamente al crear la venta"
        end
        raise Domain::ValidationError, "No se pueden registrar cobros en una venta cancelada" if record.cancelled?

        balance = record.available_to_collect
        if amount > balance
          raise Domain::ValidationError, "El cobro supera el saldo pendiente"
        end

        Payment.create!(
          sale: record,
          registered_by: actor,
          kind: "receipt",
          method: method,
          amount: amount,
          tendered_amount: method == "cash" ? tendered_amount : nil,
          external_reference: external_reference,
          idempotency_key: idempotency_key,
          occurred_at: occurred_at || Time.current
        )
      end
    end

    private

    attr_reader :actor, :sale, :amount, :method, :idempotency_key, :tendered_amount, :external_reference, :occurred_at

    def same_operation?(payment)
      payment.sale_id == sale.id &&
        payment.receipt? &&
        payment.method == method &&
        payment.amount == amount &&
        payment.tendered_amount == tendered_amount &&
        payment.original_payment_id.nil?
    end
  end
end
