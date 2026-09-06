# frozen_string_literal: true

class User < ApplicationRecord
  include Exportable
  include DatatableSearchable

  setup_exportable(
    fields: [ :full_name, :email, :created_at ],
    include: [ :role ]
  )

  configure_datatable do |config|
    config[:includes] = [ :role ]
    config[:searchable] = [
      "users.full_name",
      "users.email",
      "roles.name"
    ]
    config[:sortable] = [
      "users.full_name",
      "users.email",
      "roles.name",
      "users.created_at"
    ]
    config[:selects] = [
      "users.full_name",
      "users.email",
      "users.created_at",
      "roles.name AS role_name"
    ]
    config[:filters] = {
      role_name: {
        column: "roles.name",
        label: "Rol",
        multiple: true,
        collection: -> { Role.order(:name).pluck(:name) }
      }
    }
    config
  end

  belongs_to :role
  has_one :employee, dependent: :restrict_with_error
  has_many :created_appointments, class_name: "Appointment", foreign_key: :created_by_id, inverse_of: :created_by, dependent: :restrict_with_error
  has_many :created_sales, class_name: "Sale", foreign_key: :created_by_id, inverse_of: :created_by, dependent: :restrict_with_error
  has_many :registered_payments, class_name: "Payment", foreign_key: :registered_by_id, inverse_of: :registered_by, dependent: :restrict_with_error
  has_many :created_time_offs, class_name: "EmployeeTimeOff", foreign_key: :created_by_id, inverse_of: :created_by, dependent: :restrict_with_error

  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable

  LAST_ACTIVE_ADMIN_MESSAGE = "No se puede desactivar el último administrador.".freeze

  validates :full_name, presence: true
  validates :role, presence: true
  validate :must_keep_an_active_admin, on: :update

  scope :active, -> { where(active: true) }
  scope :admins, -> { active.joins(:role).where(roles: { code: "admin" }) }

  def self.minimum_password_length
    6
  end

  def role_name
    role&.name
  end
  alias_method :rol_name, :role_name

  def role_code
    role&.code
  end

  def admin?
    role_code == "admin"
  end

  def receptionist?
    role_code == "receptionist"
  end

  def employee_role?
    role_code == "employee"
  end

  def active_for_authentication?
    super && active?
  end

  def inactive_message
    active? ? super : :inactive
  end

  def deactivate!
    update!(active: false)
  end

  private

  def must_keep_an_active_admin
    return unless removing_last_admin_privileges?

    remaining_admin_ids = self.class.admins.lock.pluck(:id) - [ id ]
    return if remaining_admin_ids.any?

    errors.add(:base, LAST_ACTIVE_ADMIN_MESSAGE)
  end

  def removing_last_admin_privileges?
    return false unless persisted?
    return false unless stored_as_active_admin?

    deactivating = will_save_change_to_active? && !active?
    demoting = will_save_change_to_role_id? && !admin_role_id?(role_id)
    deactivating || demoting
  end

  def stored_as_active_admin?
    active_in_database && admin_role_id?(role_id_in_database)
  end

  def admin_role_id?(id)
    Role.where(id: id, code: "admin").exists?
  end
end
