# frozen_string_literal: true

class ApplicationService
  def self.call(...)
    new(...).call
  end

  private

  def authorize!(actor, action, subject)
    raise Domain::Forbidden, "No autorizado" unless actor&.active?
    raise Domain::Forbidden, "No autorizado" unless Ability.new(actor).can?(action, subject)
  end

  def with_exclusion_guard
    yield
  rescue ActiveRecord::StatementInvalid => e
    raise Domain::Conflict, "El horario ya está ocupado" if exclusion_violation?(e)
    raise
  end

  def exclusion_violation?(error)
    cause = error.cause
    cause.class.name == "PG::ExclusionViolation" || error.message.match?(/exclusion|no_overlap/i)
  end

  def business_settings
    @business_settings ||= BusinessSetting.current!
  end
end
