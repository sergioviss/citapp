# frozen_string_literal: true

class Payment < ApplicationRecord
  KINDS = %w[receipt refund].freeze
  METHODS = %w[cash card transfer].freeze

  belongs_to :sale
  belongs_to :registered_by, class_name: "User"
  belongs_to :original_payment, class_name: "Payment", optional: true
  has_many :refunds, class_name: "Payment", foreign_key: :original_payment_id, inverse_of: :original_payment, dependent: :restrict_with_error

  enum :kind, KINDS.index_with(&:itself), validate: true

  validates :method, inclusion: { in: METHODS }
  validates :amount, numericality: { greater_than: 0 }
  validates :idempotency_key, presence: true, uniqueness: true
  validates :original_payment_id, presence: true, if: :refund?
  validates :original_payment_id, absence: true, unless: :refund?
  validates :reason, presence: true, if: :refund?
  validates :tendered_amount, presence: true, if: :cash_receipt?
  validates :tendered_amount, absence: true, unless: :cash_receipt?
  validate :tendered_covers_amount
  validate :original_payment_same_sale

  before_update { prevent_mutation("No se puede modificar un pago confirmado") }
  before_destroy { prevent_mutation("No se puede eliminar un pago confirmado") }

  def cash_receipt?
    receipt? && method == "cash"
  end

  def change_amount
    return unless cash_receipt? && tendered_amount.present?

    tendered_amount - amount
  end

  def refunded_total
    refunds.sum(:amount)
  end

  def refundable_remaining
    amount - refunded_total
  end

  private

  def tendered_covers_amount
    return unless cash_receipt? && tendered_amount.present? && amount.present?
    return if tendered_amount >= amount

    errors.add(:tendered_amount, "debe ser mayor o igual al importe cobrado")
  end

  def original_payment_same_sale
    return if original_payment.blank?

    errors.add(:original_payment_id, "debe ser un cobro") unless original_payment.receipt?
    errors.add(:original_payment_id, "debe pertenecer a la misma venta") if original_payment.sale_id != sale_id
    errors.add(:original_payment_id, "no puede referirse a sí mismo") if original_payment_id == id && id.present?
  end

  def prevent_mutation(message)
    errors.add(:base, message)
    throw :abort
  end
end
