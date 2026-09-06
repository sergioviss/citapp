# frozen_string_literal: true

module Sales
  class Publish < ApplicationService
    def initialize(actor:, sale:)
      @actor = actor
      @sale = sale
    end

    def call
      authorize!(actor, :update, sale)

      ApplicationRecord.transaction do
        record = Sale.lock.find(sale.id)
        raise Domain::ValidationError, "Solo se puede publicar una venta en borrador" unless record.draft?

        lines = record.sale_items.to_a
        raise Domain::ValidationError, "La venta debe tener al menos una partida" if lines.empty?

        subtotal = lines.sum { |line| line.quantity * line.unit_price }
        discount_total = lines.sum(&:discount_amount)
        tax_total = lines.sum(&:tax_amount)
        total = subtotal - discount_total + tax_total

        unless record.subtotal == subtotal && record.discount_total == discount_total &&
               record.tax_total == tax_total && record.total == total
          record.update!(
            subtotal: subtotal,
            discount_total: discount_total,
            tax_total: tax_total
          )
          record.reload
        end

        unless record.total == total
          raise Domain::ValidationError, "Los totales de la venta no coinciden con sus partidas"
        end

        record.update!(status: "posted")
        record
      end
    end

    private

    attr_reader :actor, :sale
  end
end
