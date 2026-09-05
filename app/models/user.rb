class User < ApplicationRecord
  include Exportable
  include DatatableSearchable

  setup_exportable(
    fields: [:full_name, :email, :created_at],
    include: [:rol]
  )
configure_datatable do |config|
  config[:includes] = [:rol]
  config[:searchable] = [
    'users.full_name', 
    'users.email', 
    'rols.name'
  ]
  config[:sortable] = [
    'users.full_name', 
    'users.email', 
    'rols.name', 
    'users.created_at'
  ]
  config[:selects] = [
    'users.full_name',
    'users.email',
    'users.created_at',
    'rols.name AS rol_name'
  ]
  config[:filters] = {

    rol_name: {
      column: 'rols.name',
      label: 'Rol',
      multiple: true,
      collection: -> { Rol.pluck(:name) } 
    }
  }
  config
end
  belongs_to :rol
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable

  def self.minimum_password_length
    6 # Devise.password_length.first
  end

  def password_complexity
    # Regexp extracted from https://stackoverflow.com/questions/19605150/regex-for-password-must-contain-at-least-eight-characters-at-least-one-number-a
    return if password.blank? || password =~ /(?=.*?[A-Z])(?=.*?[a-z])(?=.*?[0-9])(?=.*?[#?!@$%^&*-])/

    errors.add :password,
               'Complexity requirement not met. Please use: 1 uppercase, 1 lowercase, 1 digit and 1 special character'
  end

  def rol_name
    rol.name
  end

  def admin?
    rol.name == 'Administrador'
  end


end
