# frozen_string_literal: true

module Availability
  # Civil-time intervals for the existing FullCalendar timeGridDay component.
  # Booking still validates real timestamptz instants under the employee lock.
  class DaySchedule
    def self.call(employee:, date:, time_zone:)
      from = date.in_time_zone(time_zone)
      to = (date + 1).in_time_zone(time_zone)
      hours = employee.active? ? employee.employee_working_hours.select { |slot| slot.weekday == date.cwday } : []
      cursor = 0
      blocked = []
      hours.sort_by(&:starts_at_seconds).each do |slot|
        blocked << [ cursor, slot.starts_at_seconds ] if slot.starts_at_seconds > cursor
        cursor = [ cursor, slot.ends_at_seconds ].max
      end
      blocked << [ cursor, 86_400 ] if cursor < 86_400
      employee.employee_time_offs.overlapping(from, to).each do |absence|
        start = absence.starts_at <= from ? 0 : seconds(absence.starts_at.in_time_zone(time_zone))
        finish = absence.ends_at >= to ? 86_400 : seconds(absence.ends_at.in_time_zone(time_zone))
        blocked << [ start, finish ]
      end
      merged = []
      blocked.sort.each do |start, finish|
        if merged.any? && merged.last.last >= start
          merged.last[1] = [ merged.last.last, finish ].max
        else
          merged << [ start, finish ]
        end
      end
      merged.map { |start, finish| { start: timestamp(date, start), end: timestamp(date, finish) } }
    end

    def self.seconds(time)
      time.hour * 3600 + time.min * 60 + time.sec
    end

    def self.timestamp(date, seconds)
      return "#{date + 1}T00:00:00" if seconds == 86_400

      "#{date}T#{format('%02d:%02d:%02d', seconds / 3600, seconds / 60 % 60, seconds % 60)}"
    end
    private_class_method :seconds, :timestamp
  end
end
