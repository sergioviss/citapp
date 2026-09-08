# frozen_string_literal: true

class ServiceCategory < ApplicationRecord
  has_many :services, foreign_key: :category_id, inverse_of: :category, dependent: :restrict_with_error
  validates :name, presence: true, uniqueness: { case_sensitive: false }

  def self.general
    find_or_create_by!(name: "General")
  end
end
