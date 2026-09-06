# frozen_string_literal: true

class Sale < ApplicationRecord
  STATUSES = %w[draft posted cancelled].freeze

  belongs_to :appointment, optional: true
  belongs_to :client
  belongs_to :created_by, class_name: "User"
  has_many :sale_items, dependent: :restrict_with_error, inverse_of: :sale
  has_many :payment_attempts, dependent: :restrict_with_error
  has_many :payments, dependent: :restrict_with_error
  has_one :sale_balance, foreign_key: :sale_id, inverse_of: :sale

  enum :status, STATUSES.index_with(&:itself), validate: true

  validates :currency, presence: true, format: { with: /\A[A-Z]{3}\z/ }
  validates :appointment_id, uniqueness: true, allow_nil: true
  validates :discount_percent, numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 100 }
  validates :exchange_rate, numericality: { greater_than: 0, less_than: 1_000_000 }, allow_nil: true
  validates :subtotal, :discount_total, :tax_total, :total, numericality: { greater_than_or_equal_to: 0 }

  before_validation :sync_total_from_components
  before_update :protect_posted_history
  before_destroy :prevent_destroy_with_history

  def amount_due
    cancelled? ? 0 : total
  end

  def computed_balance
    totals = payments.group(:kind).sum(:amount)
    amount_due - totals.fetch("receipt", 0) + totals.fetch("refund", 0)
  end

  def available_to_collect
    computed_balance - payment_attempts.pending.sum(:amount)
  end

  def ensure_no_pending_payments!
    if payment_attempts.pending.exists?
      raise Domain::Conflict, "Hay un cobro externo pendiente de confirmar; reintenta ese cobro antes de cambiar la venta"
    end
  end

  def historical?
    posted? || cancelled?
  end

  private

  def sync_total_from_components
    self.subtotal = 0 if subtotal.nil?
    self.discount_total = 0 if discount_total.nil?
    self.tax_total = 0 if tax_total.nil?
    self.total = subtotal - discount_total + tax_total
  end

  def protect_posted_history
    persisted_sale = self.class.lock.find(id)
    persisted_sale.ensure_no_pending_payments!
    if persisted_sale.payments.exists? && (changes_to_save.keys & %w[client_id currency appointment_id]).any?
      errors.add(:base, "Una venta con pagos debe conservar cliente, moneda y cita")
      throw :abort
    end
    return if persisted_sale.draft?
    # Cancellation changes status only, never historical amounts or identity.
    return if persisted_sale.posted? && cancelled? && (changes_to_save.keys - %w[status updated_at]).empty?

    errors.add(:base, "La venta publicada o cancelada no puede modificarse")
    throw :abort
  end

  def prevent_destroy_with_history
    errors.add(:base, "No se puede eliminar una venta")
    throw :abort
  end
end
