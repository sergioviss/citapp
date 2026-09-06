# frozen_string_literal: true

require "test_helper"

class Employees::ReplaceWorkingHoursTest < ActiveSupport::TestCase
  setup do
    @service = create_service!
    @employee = create_employee!(services: [ @service ])
    @client = create_client!
  end

  test "rejects a schedule that would leave scheduled appointments outside working hours" do
    appointment = book_appointment!(
      employee: @employee,
      client: @client,
      services: [ @service ],
      starts_at: local_slot("2026-06-01", 10)
    )

    error = assert_raises(Domain::Conflict) do
      Employees::ReplaceWorkingHours.call(
        actor: users(:admin),
        employee: @employee,
        slots: [ { weekday: 1, starts_at: "14:00", ends_at: "18:00" } ]
      )
    end

    assert_includes error.details[:appointment_ids], appointment.id
  end
end
