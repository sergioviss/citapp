# frozen_string_literal: true

module Payments
  class NullGateway
    def charge(amount:, currency:, idempotency_key:, method:, metadata: {})
      {
        success: true,
        reference: "null-#{idempotency_key}",
        amount: amount,
        currency: currency,
        method: method,
        metadata: metadata
      }
    end
  end
end
