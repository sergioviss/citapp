# frozen_string_literal: true

module Sales
  class SaveDraft < ApplicationService
    def initialize(actor:, client_id: nil, new_client: nil, appointment_id: nil, notes: nil, items:, sale: nil, currency: nil, exchange_rate: nil, discount_percent: nil)
      @actor = actor
      @client_id = client_id
      @new_client = new_client
      @appointment_id = appointment_id
      @notes = notes
      @items = items
      @sale = sale
      @currency = currency
      @exchange_rate = exchange_rate
      @discount_percent = discount_percent
    end

    def call
      authorize!(actor, sale ? :update : :create, sale || Sale)

      ApplicationRecord.transaction do
        record = sale ? Sale.lock.find(sale.id) : Sale.new
        raise Domain::ValidationError, "Solo se puede editar una venta en borrador" if record.persisted? && !record.draft?

        record.ensure_no_pending_payments! if record.persisted?

        appointment = appointment_id.present? ? Appointment.find(appointment_id) : record.appointment
        if new_client.present?
          authorize!(actor, :create, Client)
          if client_id.present? || appointment || Array(items).empty?
            raise Domain::ValidationError, "Elige un solo cliente y agrega al menos un servicio"
          end
          client = Client.create!(new_client.slice(:name, :phone, :email))
        else
          client = Client.find(client_id)
        end
        currency = @currency || appointment&.currency || business_settings.currency
        @source_currency = appointment&.currency || business_settings.currency

        if appointment
          raise Domain::ValidationError, "La venta debe usar el cliente de la cita" unless client.id == appointment.client_id
        end

        record.assign_attributes(
          appointment: appointment,
          client: client,
          created_by: record.created_by || actor,
          currency: currency,
          notes: notes,
          exchange_rate: @exchange_rate,
          discount_percent: @discount_percent || 0,
          status: "draft"
        )
        record.save!

        replace_items!(record)
        apply_totals!(record)
        record
      end
    end

    private

    attr_reader :actor, :client_id, :new_client, :appointment_id, :notes, :items, :sale

    def replace_items!(record)
      record.sale_items.destroy_all
      Array(items).each do |item|
        record.sale_items.create!(build_item_attrs(item))
      end
    end

    def build_item_attrs(item)
      service = Service.find(item.fetch(:service_id))
      appointment_service = item[:appointment_service_id].present? ? AppointmentService.find(item[:appointment_service_id]) : nil
      if appointment_service.nil? && !service.active?
        raise Domain::ValidationError, "El servicio no está disponible para nuevas ventas"
      end
      unit_price = item.key?(:unit_price) ? item[:unit_price] : snapshot_price(service, appointment_service)
      if !item.key?(:unit_price) && @currency && @currency != @source_currency
        unit_price = @source_currency == "MXN" ? MoneyMath.decimal(unit_price) / @exchange_rate : MoneyMath.decimal(unit_price) * @exchange_rate
        unit_price = unit_price.round(2)
      end
      discount = item[:discount_amount] || 0
      unless @discount_percent.nil?
        discount = (MoneyMath.decimal(unit_price) * MoneyMath.decimal(item[:quantity] || 1) * @discount_percent / 100).round(2)
      end
      description = item[:description].presence || appointment_service&.service_name || service.name

      {
        service: service,
        appointment_service: appointment_service,
        employee_id: item[:employee_id].presence || appointment_service&.appointment&.employee_id,
        description: description,
        quantity: item[:quantity] || 1,
        unit_price: unit_price,
        discount_amount: discount,
        tax_rate: 0
      }
    end

    def snapshot_price(service, appointment_service)
      appointment_service&.quoted_price || service.price
    end

    def apply_totals!(record)
      lines = record.sale_items.reload.to_a
      record.update!(
        subtotal: lines.sum { |line| line.quantity * line.unit_price },
        discount_total: lines.sum(&:discount_amount),
        tax_total: lines.sum(&:tax_amount)
      )
    end
  end
end
