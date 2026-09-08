# frozen_string_literal: true

module Sales
  class Cancel < ApplicationService
    def initialize(actor:, sale:)
      @actor = actor
      @sale = sale
    end

    def call
      authorize!(actor, :update, sale)

      ApplicationRecord.transaction do
        record = Sale.lock.find(sale.id)
        raise Domain::ValidationError, "La venta ya está cancelada" if record.cancelled?

        record.ensure_no_pending_payments!
        record.update!(status: "cancelled")
        record
      end
    end

    private

    attr_reader :actor, :sale
  end
end
