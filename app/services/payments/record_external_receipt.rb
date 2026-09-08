# frozen_string_literal: true

module Payments
  class RecordExternalReceipt < Operation
    def initialize(actor:, sale:, amount:, method:, idempotency_key:, gateway: nil, metadata: {})
      @actor = actor
      @sale = sale
      @amount = money(amount)
      @method = method.to_s
      @idempotency_key = normalize_key(idempotency_key)
      @gateway = gateway
      @metadata = metadata
    end

    def call
      authorize!(actor, :create, Payment)
      raise Domain::ValidationError, "Configura una pasarela de pago" unless gateway
      unless %w[card transfer].include?(method)
        raise Domain::ValidationError, "Método de cobro externo inválido"
      end
      if ApplicationRecord.connection.transaction_open?
        raise Domain::ValidationError, "El cobro externo debe iniciarse fuera de una transacción"
      end

      attempt = reserve!
      return attempt if attempt.is_a?(Payment)

      # The adapter MUST replay the same confirmed result for the same key.
      # Timeouts/exceptions leave the reservation pending, allowing recovery
      # after a process crash without losing a charge or freeing its balance.
      result = gateway.charge(amount: attempt.amount, currency: attempt.currency,
        idempotency_key: attempt.idempotency_key, method: attempt.method,
        metadata: metadata.merge(sale_id: attempt.sale_id))
      finalize!(result)
    end

    private

    attr_reader :actor, :sale, :amount, :method, :idempotency_key, :gateway, :metadata

    def reserve!
      with_operation do |record|
        existing = Payment.find_by(idempotency_key: idempotency_key)
        if existing
          idempotency_conflict! unless same_receipt?(existing)
          next existing
        end
        attempt = PaymentAttempt.find_by(idempotency_key: idempotency_key)
        if attempt
          idempotency_conflict! unless attempt.sale_id == record.id && attempt.method == method && attempt.amount == amount
          raise Domain::ValidationError, "El intento fue rechazado por la pasarela; utiliza una nueva clave" if attempt.failed?
          next attempt
        end
        if record.checkout_key.present?
          raise Domain::ValidationError, "Los cobros se registran únicamente al crear la venta"
        end
        raise Domain::ValidationError, "No se pueden registrar cobros en una venta cancelada" if record.cancelled?
        raise Domain::ValidationError, "El cobro supera el saldo disponible" if amount > record.available_to_collect

        record.payment_attempts.create!(registered_by: actor, idempotency_key: idempotency_key,
          amount: amount, currency: record.currency, method: method)
      end
    end

    def finalize!(result)
      outcome = with_operation do |record|
        existing = Payment.find_by(idempotency_key: idempotency_key)
        next existing if existing

        attempt = PaymentAttempt.find_by!(idempotency_key: idempotency_key)
        next :declined if attempt.failed?
        if result.is_a?(Hash) && result[:success] == false
          attempt.update!(status: "failed")
          next :declined
        end
        unless result.is_a?(Hash) && result[:success] == true && result[:reference].present? &&
            (!result.key?(:amount) || MoneyMath.decimal(result[:amount]) == attempt.amount) &&
            (!result.key?(:currency) || result[:currency] == attempt.currency)
          raise Domain::Conflict, "Respuesta sin confirmación válida; reintenta con la misma clave"
        end
        payment = Payment.create!(sale: record, registered_by: attempt.registered_by,
          kind: "receipt", method: attempt.method, amount: attempt.amount,
          external_reference: result[:reference], idempotency_key: idempotency_key,
          occurred_at: Time.current)
        attempt.update!(status: "succeeded", external_reference: result[:reference])
        payment
      end
      raise Domain::ValidationError, "El cobro externo fue rechazado" if outcome == :declined

      outcome
    end

    def same_receipt?(payment)
      payment.sale_id == sale.id && payment.receipt? && payment.method == method && payment.amount == amount
    end
  end
end
