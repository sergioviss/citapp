class Rol < ApplicationRecord
  include Exportable
  setup_exportable(
    fields: [:name],
    include: [] # No incluir asociaciones a menos que sea necesario
  )

    has_many :users
  end
  