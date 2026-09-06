# frozen_string_literal: true

class EmployeeWorkingHour < ApplicationRecord
  # Wall-clock times must preserve PostgreSQL's 24:00 end-of-day boundary.
  class WallClock < ActiveRecord::Type::String
    def cast(value)
      return value.strftime("%H:%M:%S") if value.respond_to?(:strftime)

      value&.to_s&.strip
    end
  end

  attribute :starts_at, WallClock.new
  attribute :ends_at, WallClock.new
  belongs_to :employee
  validates :weekday, inclusion: { in: 1..7 }
  validates :starts_at, :ends_at, presence: true
  validates :starts_at, format: { with: /\A(?:[01]\d|2[0-3]):[0-5]\d(?::[0-5]\d)?\z/ }
  validates :ends_at, format: { with: /\A(?:(?:[01]\d|2[0-3]):[0-5]\d(?::[0-5]\d)?|24:00(?::00)?)\z/ }
  validate :ends_after_starts

  def starts_at_seconds
    time_to_seconds(starts_at)
  end

  def ends_at_seconds
    time_to_seconds(ends_at)
  end

  private

  def ends_after_starts
    return if starts_at.blank? || ends_at.blank?
    return if ends_at_seconds > starts_at_seconds

    errors.add(:ends_at, "debe ser posterior al inicio; usa 24:00 para el fin del día")
  end

  def time_to_seconds(value)
    hours, minutes, seconds = value.to_s.split(":").map(&:to_i)
    hours.to_i * 3600 + minutes.to_i * 60 + seconds.to_i
  end
end
