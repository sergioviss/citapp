# frozen_string_literal: true

module Payments
  class Operation < ApplicationService
    private

    def normalize_key(value)
      key = value.to_s.downcase
      unless key.match?(/\A[0-9a-f]{8}-(?:[0-9a-f]{4}-){3}[0-9a-f]{12}\z/)
        raise Domain::ValidationError, "La clave de idempotencia debe ser un UUID válido"
      end
      key
    end

    def money(value)
      amount = MoneyMath.decimal(value)
      unless amount.finite? && amount > 0 && amount <= BigDecimal("999999999999.99") && amount == amount.round(2)
        raise Domain::ValidationError, "El importe debe ser positivo y tener como máximo dos decimales"
      end
      amount
    rescue ArgumentError, TypeError
      raise Domain::ValidationError, "Importe inválido"
    end

    # All payment entry points use key -> sale lock order, including keys
    # accidentally reused across different sales. No network calls here.
    def with_operation
      ApplicationRecord.transaction(requires_new: true) do
        connection = ApplicationRecord.connection
        connection.execute("SELECT pg_advisory_xact_lock(hashtextextended(#{connection.quote(idempotency_key)}, 0))")
        yield Sale.lock.find(sale.id)
      end
    end

    def reject_reserved_key!
      if PaymentAttempt.exists?(idempotency_key: idempotency_key)
        raise Domain::IdempotencyConflict, "La clave pertenece a un intento de cobro externo"
      end
    end

    def idempotency_conflict!
      raise Domain::IdempotencyConflict, "La clave de idempotencia ya se usó en otra operación"
    end
  end
end
