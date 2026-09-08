# frozen_string_literal: true

class Appointment < ApplicationRecord
  STATUSES = %w[scheduled completed cancelled no_show].freeze
  OCCUPYING_STATUSES = %w[scheduled completed].freeze
  RELEASING_STATUSES = %w[cancelled no_show].freeze

  belongs_to :client
  belongs_to :employee
  belongs_to :created_by, class_name: "User", optional: true
  has_many :appointment_services, -> { order(:position) }, dependent: :destroy, inverse_of: :appointment
  has_one :sale, dependent: :restrict_with_error

  accepts_nested_attributes_for :appointment_services

  enum :status, STATUSES.index_with(&:itself), validate: true

  validates :starts_at, :ends_at, :currency, presence: true
  validates :currency, format: { with: /\A[A-Z]{3}\z/ }
  validate :ends_after_starts

  scope :occupying, -> { where(status: OCCUPYING_STATUSES) }
  scope :overlapping, ->(starts_at, ends_at) {
    where("starts_at < ? AND ends_at > ?", ends_at, starts_at)
  }

  def occupying?
    OCCUPYING_STATUSES.include?(status)
  end

  private

  def ends_after_starts
    return if starts_at.blank? || ends_at.blank?
    return if ends_at > starts_at

    errors.add(:ends_at, "debe ser posterior al inicio")
  end
end
