# frozen_string_literal: true

class Service < ApplicationRecord
  belongs_to :category, class_name: "ServiceCategory", inverse_of: :services
  before_validation { self.category = ServiceCategory.general if category_id.nil? && category.nil? }
  has_many :employee_services, dependent: :restrict_with_error
  has_many :employees, through: :employee_services
  has_many :appointment_services, dependent: :restrict_with_error
  has_many :sale_items, dependent: :restrict_with_error

  validates :name, presence: true
  validates :duration_minutes, numericality: { only_integer: true, greater_than: 0 }
  validates :price, numericality: { greater_than_or_equal_to: 0 }

  scope :active, -> { where(active: true) }
end
