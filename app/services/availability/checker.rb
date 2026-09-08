# frozen_string_literal: true

module Availability
  class Checker
    def initialize(employee:, starts_at:, ends_at:, time_zone:, ignore_appointment_id: nil)
      @employee = employee
      @starts_at = starts_at
      @ends_at = ends_at
      @time_zone = time_zone
      @ignore_appointment_id = ignore_appointment_id
    end

    def validate!
      assert_active!
      assert_positive_span!
      assert_working_hours!
      assert_no_time_off!
      assert_no_appointment_overlap!
    end

    private

    attr_reader :employee, :starts_at, :ends_at, :time_zone, :ignore_appointment_id

    def assert_active!
      return if employee.active?

      raise Domain::ValidationError, "El empleado no está activo"
    end

    def assert_positive_span!
      return if ends_at > starts_at

      raise Domain::ValidationError, "El fin de la cita debe ser posterior al inicio"
    end

    def assert_working_hours!
      tz = Time.find_zone!(time_zone)
      local_start = starts_at.in_time_zone(tz)
      local_end = ends_at.in_time_zone(tz)
      hours = employee.employee_working_hours.to_a.group_by(&:weekday)

      cursor = local_start
      while cursor < local_end
        next_midnight = (cursor.to_date + 1).in_time_zone(tz).beginning_of_day
        segment_end = [ next_midnight, local_end ].min
        weekday = cursor.to_date.cwday
        from = seconds_of_day(cursor)
        to = segment_end == next_midnight ? 24 * 3600 : seconds_of_day(segment_end)

        unless covered?(hours[weekday] || [], from, to)
          raise Domain::ValidationError, "El empleado no está en horario laboral en el intervalo solicitado"
        end

        cursor = next_midnight
      end
    end

    def assert_no_time_off!
      overlapping = employee.employee_time_offs.overlapping(starts_at, ends_at)
      return unless overlapping.exists?

      raise Domain::ValidationError, "El empleado tiene una ausencia en el intervalo solicitado"
    end

    def assert_no_appointment_overlap!
      scope = employee.appointments.occupying.overlapping(starts_at, ends_at)
      scope = scope.where.not(id: ignore_appointment_id) if ignore_appointment_id
      return unless scope.exists?

      raise Domain::Conflict, "El horario ya está ocupado"
    end

    def covered?(ranges, from, to)
      return false if ranges.empty? || to <= from

      merged = ranges.map { |range| [ range.starts_at_seconds, range.ends_at_seconds ] }.sort_by(&:first)
      cursor = from
      merged.each do |range_start, range_end|
        next if range_end <= cursor
        return false if range_start > cursor

        cursor = range_end
        return true if cursor >= to
      end
      cursor >= to
    end

    def seconds_of_day(time)
      time.hour * 3600 + time.min * 60 + time.sec
    end
  end
end
