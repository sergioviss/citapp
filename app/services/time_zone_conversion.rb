# frozen_string_literal: true

module TimeZoneConversion
  module_function

  def parse!(time_zone, value, interpret_as_local:)
    raise Domain::ValidationError, "La fecha es obligatoria" if value.blank?

    tz = Time.find_zone(time_zone)
    raise Domain::ValidationError, "Zona horaria inválida" unless tz

    interpret_as_local ? local_to_utc!(tz, value) : to_utc(value)
  end

  def to_utc(value)
    time = coerce_time(value)
    time.utc
  end

  def local_to_utc!(tz, value)
    year, month, day, hour, min, sec = wall_clock_parts(value)
    timezone = TZInfo::Timezone.get(tz.tzinfo.identifier)
    local = Time.new(year, month, day, hour, min, sec)
    timezone.local_to_utc(local)
  rescue TZInfo::PeriodNotFound
    raise Domain::ValidationError, "La hora local no existe por el cambio de horario"
  rescue TZInfo::AmbiguousTime
    raise Domain::ValidationError, "La hora local es ambigua por el cambio de horario"
  end

  def wall_clock_parts(value)
    time = value.is_a?(String) ? parse_wall_clock_string(value) : value
    unless time.respond_to?(:year)
      raise Domain::ValidationError, "Fecha inválida"
    end

    [ time.year, time.month, time.day, time.hour, time.min, time.sec ]
  end

  def parse_wall_clock_string(value)
    unless value.match?(/\A\d{4}-\d{2}-\d{2}[ T]\d{2}:\d{2}(?::\d{2})?\z/)
      raise Domain::ValidationError, "Fecha inválida"
    end
    parts = value.scan(/\d+/).map(&:to_i)
    year, month, day, hour, minute, second = parts
    unless Date.valid_date?(year, month, day) && hour.between?(0, 23) && minute.between?(0, 59) && (second || 0).between?(0, 59)
      raise Domain::ValidationError, "Fecha inválida"
    end
    Time.utc(year, month, day, hour, minute, second || 0)
  end

  def coerce_time(value)
    return value.to_time if value.respond_to?(:to_time) && !value.is_a?(String)

    Time.iso8601(value)
  rescue ArgumentError, TypeError
    raise Domain::ValidationError, "Fecha inválida"
  end
end
