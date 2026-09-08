# frozen_string_literal: true

module Operations
  class SettingsController < BaseController
    def show
      @settings = BusinessSetting.current!
      allowed! :read, @settings
    end

    def update
      record = BusinessSetting.current!
      allowed! :update, record
      data = params.require(:business_setting).permit(:name, :time_zone, :currency, :usd_exchange_rate)
      record.with_lock do
        changing = (data[:time_zone].present? && data[:time_zone] != record.time_zone) ||
          (data[:currency].present? && data[:currency] != record.currency)
        if changing && (Appointment.exists? || Sale.exists? || Service.exists? || EmployeeWorkingHour.exists? || EmployeeTimeOff.exists?)
          raise Domain::Conflict, "La zona y moneda ya tienen operaciones asociadas; requieren una conversión planificada"
        end
        record.update!(data)
      end
      saved(record, location: operations_settings_path)
    end
  end
end
