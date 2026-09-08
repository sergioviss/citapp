# frozen_string_literal: true

module Operations
  class EmployeesController < BaseController
    include OperationsCatalog
    def create
      allowed! :create, Employee
      record = Employee.create!(attributes)
      saved(record, location: operations_employee_path(record), status: :created)
    end

    def show
      @employee = Employee.find(params[:id])
      allowed! :read, @employee
      @categories = ServiceCategory.includes(:services).order(:name)
      @hours = @employee.employee_working_hours.order(:weekday, :starts_at)
      @absences = @employee.employee_time_offs.order(starts_at: :desc).limit(50)
      @settings = BusinessSetting.current!
      respond_to do |format|
        format.html
        format.json { render json: @employee.as_json(include: [ :employee_services, :employee_working_hours, :employee_time_offs ]) }
      end
    end

    def edit
      show
      allowed! :update, @employee
      render :show unless performed?
    end

    def destroy
      record = Employee.find(params[:id])
      allowed! :destroy, record
      record.with_lock do
        if record.appointments.exists?
          raise Domain::Conflict, "El empleado tiene citas registradas. Puedes desactivarlo desde Editar para conservar el historial."
        end
        record.destroy!
      end
      saved({ id: record.id }, location: operations_employees_path)
    end

    def day_working_hours
      record = Employee.find(params[:id])
      allowed! :update, record
      day = Integer(params.require(:weekday))
      raise Domain::ValidationError, "Día inválido" unless (1..7).cover?(day)

      slots = params.permit(slots: [ :starts_at, :ends_at ]).fetch(:slots, [])
      slots = slots.values if slots.respond_to?(:values)
      enabled = ActiveModel::Type::Boolean.new.cast(params.require(:enabled))
      record.with_lock do
        preserved = record.employee_working_hours.where.not(weekday: day).map { |slot| slot.attributes.symbolize_keys.slice(:weekday, :starts_at, :ends_at) }
        replacement = enabled ? Array(slots).first(1).map { |slot| slot.to_h.symbolize_keys.merge(weekday: day) } : []
        if enabled && replacement.empty?
          raise Domain::ValidationError, "Indica la hora de entrada y la hora de salida"
        end
        Employees::ReplaceWorkingHours.call(actor: current_user, employee: record, slots: preserved + replacement)
      end
      saved(record, location: edit_operations_employee_path(record))
    end

    def update
      record = Employee.find(params[:id])
      allowed! :update, record
      ApplicationRecord.transaction do
        record.with_lock { record.update!(attributes) }
        hours = working_hour_slots_from_params
        Employees::ReplaceWorkingHours.call(actor: current_user, employee: record, slots: hours) unless hours.nil?
        assign_services_from_params!(record)
        record_time_off_from_params!(record)
      end
      saved(record, location: operations_employee_path(record))
    end

    def assign_services
      record = Employee.find(params[:id])
      result = Employees::AssignServices.call(actor: current_user, employee: record,
        service_ids: Array(params[:service_ids]).reject(&:blank?).map(&:to_i))
      saved(result, location: operations_employee_path(record))
    end

    def working_hours
      record = Employee.find(params[:id])
      slots = params.permit(slots: [ :weekday, :starts_at, :ends_at ]).fetch(:slots, [])
      slots = slots.values if slots.respond_to?(:values)
      slots = slots.map { |slot| slot.to_h.symbolize_keys }.reject { |slot| slot.values.all?(&:blank?) }
      result = Employees::ReplaceWorkingHours.call(actor: current_user, employee: record, slots: slots)
      saved(result, location: operations_employee_path(record))
    end

    def time_off
      record = Employee.find(params[:id])
      data = params.require(:time_off).permit(:starts_at, :ends_at, :reason).to_h.symbolize_keys
      result = Employees::RecordTimeOff.call(actor: current_user, employee: record, **data)
      saved(result, location: operations_employee_path(record), status: :created)
    end

    private

    def attributes
      fields = [ :name, :active ]
      fields << :user_id if current_user.admin?
      params.require(:employee).permit(*fields)
    end

    def working_hour_slots_from_params
      return unless params.key?(:hours)

      params.require(:hours).to_unsafe_h.each_with_object([]) do |(weekday, day), slots|
        day = day.to_h.with_indifferent_access
        next unless ActiveModel::Type::Boolean.new.cast(day[:enabled])

        starts_at, ends_at = day_entry_and_exit(day)
        raise Domain::ValidationError, "Indica la hora de entrada y la hora de salida" if starts_at.blank? || ends_at.blank?

        slots << { weekday: Integer(weekday), starts_at: starts_at, ends_at: ends_at }
      end
    end

    def day_entry_and_exit(day)
      starts_at = day[:starts_at].presence
      ends_at = day[:ends_at].presence
      return [ starts_at, ends_at ] if starts_at.present? || ends_at.present?

      day_slots = day[:slots] || []
      day_slots = day_slots.values if day_slots.respond_to?(:values) && !day_slots.is_a?(Array)
      first = Array(day_slots).map { |slot| slot.to_h.symbolize_keys }.find { |slot| slot[:starts_at].present? || slot[:ends_at].present? }
      [ first&.[](:starts_at), first&.[](:ends_at) ]
    end

    def assign_services_from_params!(record)
      return unless params.key?(:service_ids)

      Employees::AssignServices.call(
        actor: current_user,
        employee: record,
        service_ids: Array(params[:service_ids]).reject(&:blank?).map(&:to_i)
      )
    end

    def record_time_off_from_params!(record)
      data = params[:time_off]
      return if data.blank?

      permitted = data.permit(:starts_at, :ends_at, :reason)
      starts_at = permitted[:starts_at].presence
      ends_at = permitted[:ends_at].presence
      reason = permitted[:reason].presence
      return if starts_at.blank? && ends_at.blank? && reason.blank?
      raise Domain::ValidationError, "Indica el inicio y el fin de la ausencia" if starts_at.blank? || ends_at.blank?

      Employees::RecordTimeOff.call(actor: current_user, employee: record, starts_at: starts_at, ends_at: ends_at, reason: reason)
    end
  end
end
