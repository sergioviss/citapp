# frozen_string_literal: true

class Ability
  include CanCan::Ability

  def initialize(user)
    return unless user&.active?

    if user.admin?
      can :manage, :all
      return
    end

    if user.receptionist?
      can :manage, [
        Client,
        Employee,
        Service,
        EmployeeService,
        EmployeeWorkingHour,
        EmployeeTimeOff,
        Appointment,
        AppointmentService,
        Sale,
        SaleItem,
        Payment
      ]
      cannot :destroy, [ Client, Service, Sale ]
      can :read, [ BusinessSetting, SaleBalance, Role ]
      can :read, User
      return
    end

    return unless user.employee_role? && user.employee.present?

    can :read, Appointment, employee_id: user.employee.id
    can :complete, Appointment, employee_id: user.employee.id
    can :mark_no_show, Appointment, employee_id: user.employee.id
  end
end
