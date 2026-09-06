# frozen_string_literal: true

class BusinessSetting < ApplicationRecord
  SINGLETON_ID = 1

  validates :id, inclusion: { in: [ SINGLETON_ID ] }
  validates :name, presence: true
  validates :time_zone, presence: true
  validates :currency, presence: true, format: { with: /\A[A-Z]{3}\z/ }
  validate :time_zone_must_be_iana

  before_destroy { throw :abort }

  def self.current
    find_or_initialize_by(id: SINGLETON_ID)
  end

  def self.current!
    find(SINGLETON_ID)
  rescue ActiveRecord::RecordNotFound
    raise Domain::ValidationError, "Configura la zona horaria y la moneda del negocio antes de operar."
  end

  def zone
    Time.find_zone(time_zone)
  end

  private

  def time_zone_must_be_iana
    return if time_zone.blank?
    return if TZInfo::Timezone.all_identifiers.include?(time_zone)

    errors.add(:time_zone, "no es una zona IANA válida")
  end
end
