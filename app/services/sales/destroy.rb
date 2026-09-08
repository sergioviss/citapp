# frozen_string_literal: true

module Sales
  class Destroy < ApplicationService
    def initialize(actor:, sale:)
      @actor = actor
      @sale = sale
    end

    def call
      authorize!(actor, :destroy, sale)

      ApplicationRecord.transaction do
        record = Sale.lock.find(sale.id)
        Payment.where(sale_id: record.id, kind: "refund").delete_all
        Payment.where(sale_id: record.id).delete_all
        PaymentAttempt.where(sale_id: record.id).delete_all
        SaleItem.where(sale_id: record.id).delete_all
        record.delete
        record
      end
    end

    private

    attr_reader :actor, :sale
  end
end
