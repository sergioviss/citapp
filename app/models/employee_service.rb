# frozen_string_literal: true

class EmployeeService < ApplicationRecord
  belongs_to :employee
  belongs_to :service

  validates :employee_id, uniqueness: { scope: :service_id }
end
