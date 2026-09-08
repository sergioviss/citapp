# frozen_string_literal: true

module Operations
  class DashboardController < BaseController
    def index
      @settings = BusinessSetting.current!
      @date = params[:date].present? ? Date.iso8601(params[:date]) : Time.current.in_time_zone(@settings.time_zone).to_date
      from = @date.in_time_zone(@settings.time_zone)
      to = (@date + 1).in_time_zone(@settings.time_zone)
      @appointments = Appointment.accessible_by(current_ability, :read)
        .overlapping(from, to).includes(:client, :employee, :appointment_services, :sale).order(:starts_at)
      @clients = can?(:create, Appointment) ? Client.order(:name) : Client.none
      @employees = can?(:create, Appointment) ? Employee.active.order(:name) : Employee.none
      @services = can?(:create, Appointment) ? Service.active.order(:name) : Service.none
      respond_to do |format|
        format.html do
          calendar_employees = if can?(:create, Appointment)
            Employee.where(active: true).or(Employee.where(id: @appointments.map(&:employee_id)))
          else
            Employee.where(id: current_user.employee&.id)
          end
          @calendar_columns = calendar_employees.includes(:employee_working_hours, :employee_services).order(:name).map do |employee|
            { id: employee.id, name: employee.name, service_ids: employee.employee_services.map(&:service_id),
              blocked: Availability::DaySchedule.call(employee: employee, date: @date, time_zone: @settings.time_zone),
              events: @appointments.select { |appointment| appointment.employee_id == employee.id }.map do |appointment|
                { id: appointment.id, title: appointment.client.name, status: appointment.status,
                  employee_id: employee.id, client: appointment.client.as_json(only: [ :id, :name, :phone ]),
                  notes: appointment.notes, sale_id: appointment.sale&.id,
                  editable: appointment.scheduled? && can?(:update, appointment),
                  lines: appointment.appointment_services.map { |line| { id: line.service_id, name: line.service_name, duration_minutes: line.duration_minutes, price: line.quoted_price } },
                  services: appointment.appointment_services.map(&:service_name).join(", "),
                  start: appointment.starts_at.in_time_zone(@settings.time_zone).strftime("%Y-%m-%dT%H:%M:%S"),
                  end: appointment.ends_at.in_time_zone(@settings.time_zone).strftime("%Y-%m-%dT%H:%M:%S") }
              end }
          end
        end
        format.json { render json: @appointments.as_json(include: :appointment_services) }
      end
    end

    def catalogs
      allowed! :manage, Client
      @settings = BusinessSetting.current!
      @clients = Client.order(:name)
      @employees = Employee.order(:name)
      @services = Service.order(:name)
    end
  end
end
