# frozen_string_literal: true

module Employees
  class RecordTimeOff < ApplicationService
    def initialize(actor:, employee:, starts_at:, ends_at:, reason: nil, interpret_as_local: true)
      @actor = actor
      @employee = employee
      @starts_at = starts_at
      @ends_at = ends_at
      @reason = reason
      @interpret_as_local = interpret_as_local
    end

    def call
      authorize!(actor, :create, EmployeeTimeOff)

      ApplicationRecord.transaction do
        employee.lock!
        starts = TimeZoneConversion.parse!(
          business_settings.time_zone,
          starts_at,
          interpret_as_local: interpret_as_local
        )
        ends = TimeZoneConversion.parse!(
          business_settings.time_zone,
          ends_at,
          interpret_as_local: interpret_as_local
        )
        raise Domain::ValidationError, "El fin de la ausencia debe ser posterior al inicio" unless ends > starts

        conflicts = employee.appointments.scheduled.overlapping(starts, ends).to_a
        if conflicts.any?
          raise Domain::Conflict.new(
            "Hay citas programadas en el intervalo de ausencia",
            details: { appointment_ids: conflicts.map(&:id) }
          )
        end

        employee.employee_time_offs.create!(
          starts_at: starts,
          ends_at: ends,
          reason: reason,
          created_by: actor
        )
      end
    end

    private

    attr_reader :actor, :employee, :starts_at, :ends_at, :reason, :interpret_as_local
  end
end
