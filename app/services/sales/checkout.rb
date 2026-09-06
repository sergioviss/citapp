# frozen_string_literal: true

module Sales
  class Checkout < ApplicationService
    def initialize(actor:, payments: [], currency: nil, discount_percent: 0, checkout_key: nil, exchange_rate: nil, sale: nil, **attributes)
      @actor, @payments, @currency, @discount_percent = actor, payments, currency, discount_percent
      @checkout_key, @expected_rate, @sale, @attributes = checkout_key, exchange_rate, sale, attributes
    end

    def call
      authorize!(@actor, @sale ? :update : :create, @sale || Sale)
      authorize!(@actor, :create, Payment)
      key = @checkout_key.presence || SecureRandom.uuid
      unless key.match?(/\A[0-9a-f]{8}-(?:[0-9a-f]{4}-){3}[0-9a-f]{12}\z/i)
        raise Domain::ValidationError, "La clave de la venta debe ser un UUID válido"
      end

      ApplicationRecord.transaction do
        connection = ApplicationRecord.connection
        connection.execute("SELECT pg_advisory_xact_lock(hashtextextended(#{connection.quote(key.downcase)}, 0))")
        existing = Sale.find_by(checkout_key: key)
        if existing
          raise Domain::Forbidden, "No autorizado" unless existing.created_by_id == @actor.id
          next existing
        end
        if @sale
          @sale = Sale.lock.find(@sale.id)
          unless @sale.draft? && !@sale.payments.exists?
            raise Domain::ValidationError, "No se pueden registrar cobros después de guardar la venta"
          end
        end

        currency = @currency.presence || business_settings.currency
        unless %w[MXN USD].include?(currency)
          raise Domain::ValidationError, "Selecciona pesos o dólares"
        end
        rate = business_settings.usd_exchange_rate
        source = @attributes[:appointment_id].present? ? Appointment.find(@attributes[:appointment_id]).currency : business_settings.currency
        if currency != source && (!rate || !%w[MXN USD].include?(source))
          raise Domain::ValidationError, "Configura el tipo de cambio en Configuración antes de convertir la moneda"
        end
        if @expected_rate.present? && decimal(@expected_rate) != rate
          raise Domain::Conflict, "El tipo de cambio cambió. Recarga la venta para revisar los importes"
        end
        discount = decimal(@discount_percent)
        unless discount.between?(0, 100) && discount == discount.round(2)
          raise Domain::ValidationError, "El descuento debe estar entre 0 y 100 y tener máximo dos decimales"
        end

        record = SaveDraft.call(actor: @actor, sale: @sale, **@attributes,
          currency: currency, exchange_rate: rate, discount_percent: discount)
        record.update!(checkout_key: key, created_by: @actor)
        record_payments!(record)
        Publish.call(actor: @actor, sale: record)
      end
    end

    private

    def decimal(value)
      number = MoneyMath.decimal(value)
      raise ArgumentError unless number.finite?
      number
    rescue ArgumentError, TypeError
      raise Domain::ValidationError, "Importe inválido"
    end

    def record_payments!(record)
      rows = Array(@payments).map(&:symbolize_keys)
      unless rows.size.between?(1, 2) && rows.map { |row| row[:method] }.uniq.size == rows.size
        raise Domain::ValidationError, "Registra uno o dos métodos de pago distintos"
      end
      rows.each do |row|
        row[:amount] = decimal(row[:amount])
        unless Payment::METHODS.include?(row[:method]) && row[:amount] >= 0 && row[:amount] == row[:amount].round(2) && row[:amount] < 1_000_000_000_000
          raise Domain::ValidationError, "Método o importe de pago inválido"
        end
        if row[:amount].zero? && !(record.total.zero? && rows.one?)
          raise Domain::ValidationError, "Cada método de pago debe tener un monto mayor a cero"
        end
      end
      paid = rows.sum { |row| row[:amount] }
      change = paid - record.total
      raise Domain::ValidationError, "El monto pagado debe cubrir el total de la venta" if change.negative?
      cash = rows.find { |row| row[:method] == "cash" }
      if change.positive? && (!cash || change >= cash[:amount])
        raise Domain::ValidationError, "Solo se puede dar cambio del efectivo aplicado a la venta"
      end
      rows.each do |row|
        amount = row[:amount] - (row[:method] == "cash" ? change : 0)
        next if amount.zero?
        Payments::RecordReceipt.call(actor: @actor, sale: record, amount: amount, method: row[:method],
          tendered_amount: row[:method] == "cash" ? row[:amount] : nil, idempotency_key: SecureRandom.uuid)
      end
    end
  end
end
