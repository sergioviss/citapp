# frozen_string_literal: true

class Client < ApplicationRecord
  has_many :appointments, dependent: :restrict_with_error
  has_many :sales, dependent: :restrict_with_error

  validates :name, presence: true
end
