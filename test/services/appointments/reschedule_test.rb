# frozen_string_literal: true

require "test_helper"

class Appointments::RescheduleTest < ActiveSupport::TestCase
  setup do
    @service = create_service!(duration_minutes: 30)
    @employee = create_employee!(services: [ @service ])
    @client = create_client!
    @appointment = book_appointment!(
      employee: @employee,
      client: @client,
      services: [ @service ],
      starts_at: local_slot("2026-06-01", 10)
    )
  end

  test "moves a scheduled appointment to a free slot" do
    result = Appointments::Reschedule.call(
      actor: users(:receptionist),
      appointment: @appointment,
      starts_at: local_slot("2026-06-01", 16)
    )

    assert_equal 16, result.starts_at.in_time_zone("America/Mexico_City").hour
  end

  test "rejects rescheduling a completed appointment" do
    Appointments::ChangeStatus.call(actor: users(:admin), appointment: @appointment, status: "completed")

    error = assert_raises(Domain::ValidationError) do
      Appointments::Reschedule.call(
        actor: users(:receptionist),
        appointment: @appointment.reload,
        starts_at: local_slot("2026-06-01", 16)
      )
    end
    assert_match(/programadas/i, error.message)
  end
end
