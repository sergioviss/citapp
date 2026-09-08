# frozen_string_literal: true

module Operations
  class PaymentsController < BaseController
    def create
      Sale.find(params[:sale_id])
      allowed! :create, Payment
      raise Domain::ValidationError, "Los cobros se registran únicamente al crear la venta"
    end

    def refund
      sale = Sale.find(params[:sale_id])
      data = params.require(:payment).permit(:original_payment_id, :amount, :method, :reason, :idempotency_key).to_h.symbolize_keys
      original = sale.payments.find(data.delete(:original_payment_id))
      record = Payments::RecordRefund.call(actor: current_user, sale: sale, original_payment: original, **data)
      saved(record, location: operations_sale_path(sale), status: :created)
    end

    def external
      sale = Sale.find(params[:sale_id])
      data = params.require(:payment).permit(:amount, :method, :idempotency_key).to_h.symbolize_keys
      allowed! :create, Payment
      unless sale.payment_attempts.pending.exists?(idempotency_key: data[:idempotency_key])
        raise Domain::ValidationError, "Los cobros se registran únicamente al crear la venta"
      end
      record = Payments::RecordExternalReceipt.call(actor: current_user, sale: sale,
        gateway: Rails.configuration.x.payment_gateway, **data)
      saved(record, location: operations_sale_path(sale), status: :created)
    rescue Timeout::Error, IOError, SocketError
      operation_error("El resultado del cobro está pendiente; reintenta con la misma clave", :service_unavailable)
    end
  end
end
