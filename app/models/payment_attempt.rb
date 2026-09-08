# frozen_string_literal: true

class PaymentAttempt < ApplicationRecord
  belongs_to :sale
  belongs_to :registered_by, class_name: "User"
  enum :status, %w[pending succeeded failed].index_with(&:itself), validate: true
  validates :idempotency_key, presence: true, uniqueness: true
  validates :amount, numericality: { greater_than: 0 }
  validates :currency, format: { with: /\A[A-Z]{3}\z/ }
  validates :method, inclusion: { in: %w[card transfer] }
end
