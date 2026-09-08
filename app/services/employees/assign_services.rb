# frozen_string_literal: true

module Employees
  class AssignServices < ApplicationService
    def initialize(actor:, employee:, service_ids:)
      @actor = actor
      @employee = employee
      @service_ids = Array(service_ids).uniq
    end

    def call
      authorize!(actor, :update, employee)

      ApplicationRecord.transaction do
        employee.lock!
        current_ids = employee.employee_services.pluck(:service_id)
        (current_ids - service_ids).each do |id|
          employee.employee_services.find_by!(service_id: id).destroy!
        end
        (service_ids - current_ids).each do |id|
          employee.employee_services.create!(service_id: id)
        end
        employee.employee_services.reload
      end
    end

    private

    attr_reader :actor, :employee, :service_ids
  end
end
