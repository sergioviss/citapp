# frozen_string_literal: true

module Appointments
  class Reschedule < ApplicationService
    def initialize(actor:, appointment:, starts_at:, ends_at: nil, employee_id: nil, interpret_as_local: true,
      service_ids: nil, client_id: nil, new_client: nil, notes: nil)
      @actor = actor
      @appointment = appointment
      @starts_at = starts_at
      @ends_at = ends_at
      @employee_id = employee_id
      @interpret_as_local = interpret_as_local
      @service_ids = service_ids
      @client_id = client_id
      @new_client = new_client
      @notes = notes
    end

    def call
      authorize!(actor, :update, appointment)

      with_exclusion_guard do
        ApplicationRecord.transaction do
          # Lock employees before appointments, as availability changes do.
          expected_employee_id = Appointment.where(id: appointment.id).pick(:employee_id)
          employee_ids = [ expected_employee_id, employee_id || expected_employee_id ].map(&:to_i).uniq.sort
          employees = Employee.where(id: employee_ids).order(:id).lock.index_by(&:id)
          appointment.lock!
          authorize!(actor, :update, appointment)
          if appointment.employee_id != expected_employee_id
            raise Domain::Conflict, "La cita cambió de empleado; vuelve a intentarlo"
          end
          raise Domain::ValidationError, "Solo se pueden reprogramar citas programadas" unless appointment.scheduled?
          employee = employees.fetch((employee_id || appointment.employee_id).to_i) do
            raise ActiveRecord::RecordNotFound, "Empleado no encontrado"
          end
          original_lines = appointment.appointment_services.includes(:service).to_a
          original_ids = original_lines.map(&:service_id)
          selected_ids = @service_ids.nil? ? original_ids : @service_ids.map(&:to_i)
          changed_services = selected_ids != original_ids
          if appointment.sale && (changed_services || @new_client.present? || (@client_id.present? && @client_id.to_i != appointment.client_id))
            raise Domain::ValidationError, "La cita tiene una venta: conserva su cliente y servicios"
          end
          services = selected_ids.map { |id| Service.find(id) }
          raise Domain::ValidationError, "La cita debe incluir al menos un servicio" if services.empty?

          snapshots = services.map do |service|
            previous = original_lines.find { |line| line.service_id == service.id }
            raise Domain::ValidationError, "El servicio no está disponible" if previous.nil? && !service.active?
            { service: service, service_name: previous&.service_name || service.name,
              duration_minutes: previous&.duration_minutes || service.duration_minutes,
              quoted_price: previous&.quoted_price || service.price }
          end

          services.each do |service|
            unless employee.employee_services.exists?(service_id: service.id)
              raise Domain::ValidationError, "El empleado no puede realizar el servicio #{service.name}"
            end
          end

          required = snapshots.sum { |line| line[:duration_minutes] } * 60
          starts = TimeZoneConversion.parse!(
            business_settings.time_zone,
            starts_at,
            interpret_as_local: interpret_as_local
          )
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

          Availability::Checker.new(
            employee: employee,
            starts_at: starts,
            ends_at: ends,
            time_zone: business_settings.time_zone,
            ignore_appointment_id: appointment.id
          ).validate!

          client = ClientSelection.call(actor: actor,
            client_id: @new_client.present? ? @client_id : (@client_id.presence || appointment.client_id), new_client: @new_client)
          changes = { employee: employee, starts_at: starts, ends_at: ends, client: client }
          changes[:notes] = @notes unless @notes.nil?
          appointment.update!(changes)
          if changed_services
            appointment.appointment_services.destroy_all
            snapshots.each_with_index { |line, index| appointment.appointment_services.create!(**line, position: index + 1) }
          end
          appointment
        end
      end
    end

    private

    attr_reader :actor, :appointment, :starts_at, :ends_at, :employee_id, :interpret_as_local
  end
end
