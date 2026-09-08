# frozen_string_literal: true

module Employees
  class ReplaceWorkingHours < ApplicationService
    def initialize(actor:, employee:, slots:)
      @actor = actor
      @employee = employee
      @slots = slots
    end

    def call
      authorize!(actor, :update, employee)

      with_exclusion_guard do
        ApplicationRecord.transaction do
          employee.lock!
          employee.employee_working_hours.delete_all

          slots.each do |slot|
            employee.employee_working_hours.create!(
              weekday: slot.fetch(:weekday),
              starts_at: slot.fetch(:starts_at),
              ends_at: slot.fetch(:ends_at)
            )
          end
          employee.employee_working_hours.reload

          conflicting_ids = employee.appointments.scheduled.filter_map do |appointment|
            Availability::Checker.new(
              employee: employee,
              starts_at: appointment.starts_at,
              ends_at: appointment.ends_at,
              time_zone: business_settings.time_zone,
              ignore_appointment_id: appointment.id
            ).validate!
            nil
          rescue Domain::ValidationError, Domain::Conflict
            appointment.id
          end

          if conflicting_ids.any?
            raise Domain::Conflict.new(
              "El nuevo horario deja citas programadas fuera de disponibilidad",
              details: { appointment_ids: conflicting_ids }
            )
          end

          employee.employee_working_hours
        end
      end
    end

    private

    attr_reader :actor, :employee, :slots
  end
end
