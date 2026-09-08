# frozen_string_literal: true

module Domain
  class Error < StandardError
    attr_reader :code, :details

    def initialize(message = nil, code: nil, details: nil)
      super(message)
      @code = code
      @details = details
    end
  end

  class Forbidden < Error; end
  class Conflict < Error; end
  class ValidationError < Error; end
  class IdempotencyConflict < Conflict; end
end
