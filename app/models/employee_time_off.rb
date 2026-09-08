# frozen_string_literal: true

class EmployeeTimeOff < ApplicationRecord
  self.table_name = "employee_time_off"
  belongs_to :employee
  belongs_to :created_by, class_name: "User"

  validates :starts_at, :ends_at, presence: true
  validate :ends_after_starts

  scope :overlapping, ->(starts_at, ends_at) {
    where("starts_at < ? AND ends_at > ?", ends_at, starts_at)
  }

  private

  def ends_after_starts
    return if starts_at.blank? || ends_at.blank?
    return if ends_at > starts_at

    errors.add(:ends_at, "debe ser posterior al inicio")
  end
end
