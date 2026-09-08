# frozen_string_literal: true

module Appointments
  class Book < ApplicationService
    def initialize(actor:, client_id: nil, new_client: nil, employee_id:, service_ids:, starts_at:, ends_at: nil, notes: nil, interpret_as_local: true)
      @actor = actor
      @client_id = client_id
      @new_client = new_client
      @employee_id = employee_id
      @service_ids = Array(service_ids)
      @starts_at = starts_at
      @ends_at = ends_at
      @notes = notes
      @interpret_as_local = interpret_as_local
    end

    def call
      authorize!(actor, :create, Appointment)

      with_exclusion_guard do
        ApplicationRecord.transaction do
          employee = Employee.lock.find(employee_id)
          client = ClientSelection.call(actor: actor, client_id: client_id, new_client: @new_client)
          services = load_services!(employee)
          starts, ends = resolve_interval(services)

          Availability::Checker.new(
            employee: employee,
            starts_at: starts,
            ends_at: ends,
            time_zone: business_settings.time_zone
          ).validate!

          appointment = Appointment.create!(
            client: client,
            employee: employee,
            created_by: actor,
            currency: business_settings.currency,
            starts_at: starts,
            ends_at: ends,
            status: "scheduled",
            notes: notes
          )

          services.each_with_index do |service, index|
            appointment.appointment_services.create!(
              service: service,
              position: index + 1,
              service_name: service.name,
              duration_minutes: service.duration_minutes,
              quoted_price: service.price
            )
          end

          appointment
        end
      end
    end

    private

    attr_reader :actor, :client_id, :employee_id, :service_ids, :starts_at, :ends_at, :notes, :interpret_as_local

    def load_services!(employee)
      raise Domain::ValidationError, "La cita debe incluir al menos un servicio" if service_ids.empty?

      services_by_id = Service.where(id: service_ids).index_by(&:id)
      assigned_ids = employee.employee_services.where(service_id: service_ids).pluck(:service_id)
      service_ids.map do |id|
        service = services_by_id.fetch(id.to_i) { raise ActiveRecord::RecordNotFound, "Servicio no encontrado" }
        unless service.active?
          raise Domain::ValidationError, "El servicio #{service.name} no está disponible"
        end
        unless assigned_ids.include?(service.id)
          raise Domain::ValidationError, "El empleado no puede realizar el servicio #{service.name}"
        end
        service
      end
    end

    def resolve_interval(services)
      starts = TimeZoneConversion.parse!(
        business_settings.time_zone,
        starts_at,
        interpret_as_local: interpret_as_local
      )
      required = services.sum(&:duration_minutes) * 60
      ends = if ends_at.present?
        TimeZoneConversion.parse!(
          business_settings.time_zone,
          ends_at,
          interpret_as_local: interpret_as_local
        )
      else
        starts + required
      end

      if required > (ends - starts).to_i
        raise Domain::ValidationError, "La suma de duraciones no cabe en el intervalo reservado"
      end

      [ starts, ends ]
    end
  end
end
