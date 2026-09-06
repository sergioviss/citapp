# frozen_string_literal: true

module Operations
  class AppointmentsController < BaseController
    def create
      data = appointment_attributes
      data[:service_ids] = Array(data[:service_ids]).reject(&:blank?)
      record = Appointments::Book.call(actor: current_user, **data)
      saved(record.as_json(include: :appointment_services), location: agenda_location(record), status: :created)
    end

    def reschedule
      data = appointment_attributes
      data.delete(:employee_id) if data[:employee_id].blank?
      record = Appointments::Reschedule.call(actor: current_user, appointment: Appointment.find(params[:id]), **data)
      saved(record, location: agenda_location(record))
    end

    def change_status
      record = Appointments::ChangeStatus.call(actor: current_user,
        appointment: Appointment.find(params[:id]), status: params.require(:status))
      saved(record, location: agenda_location(record))
    end

    private

    def appointment_attributes
      params.require(:appointment).permit(:client_id, :employee_id, :starts_at, :ends_at, :notes,
        service_ids: [], new_client: [ :name, :phone, :email ]).to_h.symbolize_keys
    end

    def agenda_location(record)
      operations_root_path(date: record.starts_at.in_time_zone(BusinessSetting.current!.time_zone).to_date.iso8601)
    end
  end
end
