# frozen_string_literal: true

module Appointments
  class ChangeStatus < ApplicationService
    ALLOWED = {
      "scheduled" => %w[completed cancelled no_show]
    }.freeze

    def initialize(actor:, appointment:, status:)
      @actor = actor
      @appointment = appointment
      @status = status.to_s
    end

    def call
      with_exclusion_guard do
        ApplicationRecord.transaction do
          appointment.lock!
          authorize_status_change!
          unless ALLOWED.fetch(appointment.status, []).include?(status)
            raise Domain::ValidationError, "No se puede cambiar la cita de #{appointment.status} a #{status}"
          end
          appointment.update!(status: status)
          appointment
        end
      end
    end

    private

    attr_reader :actor, :appointment, :status

    def authorize_status_change!
      action = case status
      when "completed" then :complete
      when "no_show" then :mark_no_show
      else :update
      end

      authorize!(actor, action, appointment)
    end
  end
end
