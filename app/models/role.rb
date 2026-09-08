# frozen_string_literal: true

class Role < ApplicationRecord
  CODES = %w[admin receptionist employee].freeze

  include Exportable
  setup_exportable(fields: [ :code, :name ], include: [])

  has_many :users, dependent: :restrict_with_error

  validates :code, presence: true, uniqueness: true
  validates :name, presence: true
  validates :code, :name, format: { without: /\A\s+\z/ }
end
