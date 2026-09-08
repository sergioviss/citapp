# frozen_string_literal: true

require "test_helper"

class Appointments::ChangeStatusTest < ActiveSupport::TestCase
  setup do
    @service = create_service!
    @employee = create_employee!(user: users(:employee), services: [ @service ])
    @client = create_client!
    @appointment = book_appointment!(
      employee: @employee,
      client: @client,
      services: [ @service ],
      starts_at: local_slot("2026-06-01", 10)
    )
  end

  test "employee can complete own appointment" do
    result = Appointments::ChangeStatus.call(actor: users(:employee), appointment: @appointment, status: "completed")
    assert result.completed?
  end

  test "employee can mark own appointment as no_show" do
    result = Appointments::ChangeStatus.call(actor: users(:employee), appointment: @appointment, status: "no_show")
    assert result.no_show?
  end

  test "employee cannot cancel appointments" do
    assert_raises(Domain::Forbidden) do
      Appointments::ChangeStatus.call(actor: users(:employee), appointment: @appointment, status: "cancelled")
    end
  end

  test "cancelled appointments free the agenda" do
    Appointments::ChangeStatus.call(actor: users(:receptionist), appointment: @appointment, status: "cancelled")

    second = book_appointment!(
      employee: @employee,
      client: @client,
      services: [ @service ],
      starts_at: local_slot("2026-06-01", 10)
    )
    assert second.scheduled?
  end
end
