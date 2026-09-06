# frozen_string_literal: true

class SaleItem < ApplicationRecord
  belongs_to :sale, inverse_of: :sale_items
  belongs_to :service
  belongs_to :appointment_service, optional: true

  validates :description, presence: true
  validates :quantity, numericality: { only_integer: true, greater_than: 0 }
  validates :unit_price, numericality: { greater_than_or_equal_to: 0 }
  validates :discount_amount, numericality: { greater_than_or_equal_to: 0 }
  validates :tax_rate, numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 1 }
  validates :appointment_service_id, uniqueness: true, allow_nil: true
  validate :discount_within_line
  validate :appointment_service_matches_sale

  before_validation :apply_line_arithmetic
  before_save :protect_posted_sale
  before_destroy :protect_posted_sale

  private

  def apply_line_arithmetic
    return if quantity.blank? || unit_price.blank? || discount_amount.blank? || tax_rate.blank?

    amounts = MoneyMath.line_amounts(
      quantity: quantity,
      unit_price: unit_price,
      discount_amount: discount_amount,
      tax_rate: tax_rate
    )
    self.tax_amount = amounts[:tax_amount]
    self.total = amounts[:total]
  end

  def discount_within_line
    return if quantity.blank? || unit_price.blank? || discount_amount.blank?

    max = quantity * unit_price
    return if discount_amount >= 0 && discount_amount <= max

    errors.add(:discount_amount, "debe estar entre 0 y el importe de la partida")
  end

  def appointment_service_matches_sale
    return if appointment_service.blank?

    if sale&.appointment_id.blank?
      errors.add(:appointment_service_id, "solo aplica a una venta vinculada a una cita")
      return
    end

    if appointment_service.appointment_id != sale.appointment_id
      errors.add(:appointment_service_id, "debe pertenecer a la cita de esta venta")
    end

    if appointment_service.service_id != service_id
      errors.add(:appointment_service_id, "debe corresponder al mismo servicio")
    end
  end

  def protect_posted_sale
    ids = [ sale_id, sale_id_in_database ].compact.uniq.sort
    parents = Sale.where(id: ids).order(:id).lock.to_a
    parents.each(&:ensure_no_pending_payments!)
    return if parents.any? && parents.all?(&:draft?)

    errors.add(:base, "No se pueden modificar partidas de una venta publicada o cancelada")
    throw :abort
  end
end
