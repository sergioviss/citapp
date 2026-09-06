# frozen_string_literal: true

class Employee < ApplicationRecord
  belongs_to :user, optional: true
  has_many :employee_services, dependent: :destroy
  has_many :services, through: :employee_services
  has_many :employee_working_hours, dependent: :destroy
  has_many :employee_time_offs, dependent: :destroy
  has_many :appointments, dependent: :restrict_with_error

  validates :name, presence: true
  validates :user_id, uniqueness: true, allow_nil: true

  scope :active, -> { where(active: true) }

  def performs?(service)
    employee_services.exists?(service_id: service.id)
  end
end
