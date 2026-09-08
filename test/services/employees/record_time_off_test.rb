# frozen_string_literal: true

require "test_helper"

class Employees::RecordTimeOffTest < ActiveSupport::TestCase
  setup do
    @service = create_service!
    @employee = create_employee!(services: [ @service ])
    @client = create_client!
  end

  test "returns conflicting scheduled appointments" do
    appointment = book_appointment!(
      employee: @employee,
      client: @client,
      services: [ @service ],
      starts_at: local_slot("2026-06-01", 10)
    )

    error = assert_raises(Domain::Conflict) do
      Employees::RecordTimeOff.call(
        actor: users(:admin),
        employee: @employee,
        starts_at: local_slot("2026-06-01", 9),
        ends_at: local_slot("2026-06-01", 12)
      )
    end

    assert_includes error.details[:appointment_ids], appointment.id
  end

  test "creates time off when the agenda is free" do
    record = Employees::RecordTimeOff.call(
      actor: users(:admin),
      employee: @employee,
      starts_at: local_slot("2026-06-01", 9),
      ends_at: local_slot("2026-06-01", 12)
    )

    assert record.persisted?
    assert_equal @employee.id, record.employee_id
  end
end
