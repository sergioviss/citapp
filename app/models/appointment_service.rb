# frozen_string_literal: true

class AppointmentService < ApplicationRecord
  belongs_to :appointment, inverse_of: :appointment_services
  belongs_to :service
  has_one :sale_item, dependent: :restrict_with_error

  validates :position, numericality: { only_integer: true, greater_than: 0 }
  validates :service_name, presence: true
  validates :duration_minutes, numericality: { only_integer: true, greater_than: 0 }
  validates :quoted_price, numericality: { greater_than_or_equal_to: 0 }
  validates :position, uniqueness: { scope: :appointment_id }
end
